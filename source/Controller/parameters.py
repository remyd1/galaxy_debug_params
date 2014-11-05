"""
Parameters.py (Galaxy Controller)

Author: Aurelien Bernard (Institut des Sciences de l'Evolution de Montpellier - ISE-M)
Updates - fix : Remy Dernat (Institut des Sciences de l'Evolution de Montpellier - ISE-M)
Version: 1.2.3
Version date: 02-05-2014
"""
# Python imports
import logging
import os
import string
import shutil
import urllib
import re
import socket
import pprint
from cgi import escape, FieldStorage
from collections import OrderedDict

# Galaxy imports
from galaxy.web.base.controller import *
from galaxy.web.framework.helpers import time_ago, iff, grids

from galaxy import model, util, datatypes, jobs, web
from galaxy.web import url_for
from galaxy.datatypes.data import nice_size


pp = pprint.PrettyPrinter(indent=4, depth=50)


# Column Classes
class NameColumn( grids.TextColumn ):

    def get_value( self, trans, grid, history ):
        return history.get_display_name()

class DatasetsCounterColumn( grids.GridColumn ):

    def get_value( self, trans, grid, history ):
        # Build query to get (state, count) pairs.
        cols_to_select = [ trans.app.model.Dataset.table.c.state, func.count( '*' ) ]
        from_obj = trans.app.model.HistoryDatasetAssociation.table.join( trans.app.model.Dataset.table )
        where_clause = and_( trans.app.model.HistoryDatasetAssociation.table.c.history_id == history.id,
                             trans.app.model.HistoryDatasetAssociation.table.c.deleted == False,
                             trans.app.model.HistoryDatasetAssociation.table.c.visible == True,
                              )
        group_by = trans.app.model.Dataset.table.c.state
        query = select( columns=cols_to_select,
                        from_obj=from_obj,
                        whereclause=where_clause,
                        group_by=group_by )

        # Process results.
        state_count_dict = {}
        for row in trans.sa_session.execute( query ):
            state, count = row
            state_count_dict[ state ] = count
        rval = []
        for state in ( 'ok', 'running', 'queued', 'error' ):
            count = state_count_dict.get( state, 0 )
            if count:
                rval.append( '<div class="count-box state-color-%s">%s</div>' % ( state, count ) )
            else:
                rval.append( '' )
        return rval

# Grids
class BasicGrid( grids.Grid ):

    # Grid definition
    title = "Accessible Histories"

    model_class = model.History
    template='/parameters/grid.mako'

    default_sort_key = "-update_time"
    num_rows_per_page = 20
    use_paging = True
    use_async = True

    columns = [
        grids.TextColumn( "Name", key="name", attach_popup=True ),
        #DatasetsCounterColumn( "Datasets", key="datasets_by_state", ncells=4, sortable=False ),
        DatasetsCounterColumn( "Datasets", key="datasets_by_state", sortable=False ),
        grids.GridColumn( "Size on Disk", key="get_disk_size_bytes", format=nice_size, sortable=False ),
        grids.GridColumn( "Created", key="create_time", format=time_ago ),
        grids.GridColumn( "Last Updated", key="update_time", format=time_ago )
    ]

    columns.append( grids.MulticolFilterColumn( "filter by history name", cols_to_filter=[ columns[0] ], key="free-text-search", visible=False, filterable="standard" ) )

    operations = [
        grids.GridOperation( "display_history_parameters", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "display_history_parameters__reverse_order", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "download_parameters", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
    ]

    def get_current_item( self, trans, **kwargs ):
        return trans.get_history()

    def apply_query_filter( self, trans, query, **kwargs ):
        return query.filter_by( user = trans.user, deleted = False, purged = False )


class AdminGrid( grids.Grid ):

    # Grid definition
    title = "Accessible Histories (Admin)"

    model_class = model.History
    template='/parameters/grid.mako'

    default_sort_key = "-update_time"
    num_rows_per_page = 20
    use_paging = True
    use_async = True

    columns = [
        grids.TextColumn( "Name", key="name", attach_popup=True ),
        #DatasetsCounterColumn( "Datasets", key="datasets_by_state", ncells=4, sortable=False ),
        DatasetsCounterColumn( "Datasets", key="datasets_by_state", sortable=False ),
        grids.TextColumn( "Size on Disk", key="get_disk_size_bytes", format=nice_size, sortable=False ),
        grids.GridColumn( "Created", key="create_time", format=time_ago ),
        grids.GridColumn( "Last Updated", key="update_time", format=time_ago ),
        grids.OwnerColumn( "Owner", key="username", model_class=model.User )
    ]

    columns.append( grids.MulticolFilterColumn( "filter by history name or owner name", cols_to_filter=[ columns[0], columns[5] ], key="free-text-search", visible=False, filterable="standard" ) )

    operations = [
        grids.GridOperation( "display_history_parameters", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "display_history_parameters__reverse_order", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "download_parameters", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "debug_command_lines", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False ),
        grids.GridOperation( "generate_shell_script", allow_multiple=False, condition=( lambda item: not item.deleted ), async_compatible=False )
    ]

    def get_current_item( self, trans, **kwargs ):
        return trans.get_history()

    def build_initial_query( self, trans, **kwargs ):
        # Join so that searching history.user makes sense.
        return trans.sa_session.query( self.model_class ).join( model.User.table )

    def apply_query_filter( self, trans, query, **kwargs ):
        return query.filter( self.model_class.deleted == False).filter( self.model_class.purged == False)


class ParametersController( BaseUIController, UsesHistoryMixin ):

    ## Grid instance
    basic_grid = BasicGrid()
    admin_grid = AdminGrid()

    ## Note: this method is kept here for compatibility with old galaxy instance
    ## In late Galaxy versions (January 2013 or later) this method is in the util class
    def _string_as_bool_or_none( self, string_to_check ):
        """
        Returns True, None or False based on the argument:
        True if passed True, 'True', 'Yes', or 'On'
        None if passed None or 'None'
        False otherwise

        Note: string comparison is case-insensitive so lowercase versions of those
        function equivalently.
        """

        string_to_check = str( string_to_check ).lower()
        if string_to_check in ( 'true', 'yes', 'on' ):
            return True
        elif string_to_check == 'none':
            return None
        else:
            return False


    @web.expose
    def index( self, trans, **kwd ):
        params = util.Params( kwd )
        message = util.restore_text( params.get( 'message', ''  ) )
        status = params.get( 'status', 'done' )
        default_action = params.get( 'default_action', None )
        return trans.fill_template( "/parameters/index.mako",
                                    default_action=default_action,
                                    message=message,
                                    status=status )



    def _list_std( self, trans, **kwargs ):
        """List user accessible histories"""

        if 'operation' in kwargs:
            # Get operation and history id from kwargs (additional params)
            operation = kwargs['operation']
            selected_history_id = kwargs['id']

            # Load the history and ensure it all belong to the current user
            history = self.get_history( trans, selected_history_id )

            if history:
                # Ensure history is owned by current user
                    if history.user_id != None and trans.user:
                        assert trans.user.id == history.user_id, "History does not belong to current user"
            else:
                log.warn( "Invalid history id '%r' passed to list", selected_history_id )

            # Deal with possible operations
            if operation == "display_history_parameters":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id) )
            elif operation == "display_history_parameters__reverse_order":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id, reverse_order=True) )
            elif operation == "download_parameters":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id, as_xml=True, to_ext=True) )

            trans.sa_session.flush()


    def _list_admin( self, trans, **kwargs ):
        """List all available histories"""

        if 'operation' in kwargs:
            # Get operation and history id from kwargs (additional params)
            operation = kwargs['operation']
            selected_history_id = kwargs['id']

            # Load the history
            history = self.get_history( trans, selected_history_id, check_ownership=False )

            if not history:
                log.warn( "Invalid history id '%r' passed to list", selected_history_id )

            # Deal with possible operations
            if operation == "display_history_parameters":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id) )
            elif operation == "display_history_parameters__reverse_order":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id, reverse_order=True) )
            elif operation == "download_parameters":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='history_parameters', full_screen='False', history_id=selected_history_id, as_xml=True, to_ext=True) )
            elif operation == "debug_command_lines":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='command_lines', target="_blank", full_screen='False', history_id=selected_history_id) )
            elif operation == "generate_shell_script":
                return trans.response.send_redirect( web.url_for( controller='/parameters', action='command_lines', target="_blank", full_screen='False', history_id=selected_history_id, to_ext=True) )

            trans.sa_session.flush()


    @web.expose
    @web.require_login()
    def list( self, trans, **kwargs ):
        """Build history list depending on the user status"""

        if trans.user_is_admin():
            self._list_admin( trans, **kwargs )
            return self.admin_grid( trans, **kwargs )
        else:
            self._list_std( trans, **kwargs )
            return self.basic_grid( trans, **kwargs )


    @web.expose
    @web.require_login()
    @web.require_admin
    def command_lines( self, trans, to_ext=False, show_deleted=False, show_hidden=False, reverse_order=False, history_id=None, full_screen=True, **kwd ):
        """
        Display XML command block and executed command lines for current/active history
        """

        # Initializations
        job_objects = {}
        tool_objects = {}
        First_dataset_by_job = OrderedDict()
        Associated_datasets_by_job = {}
        check_ownership = check_accessible = True

        # Reject non authorized access
        if trans.app.config.require_login and not trans.user:
            return trans.fill_template( '/no_access.mako', message='Please log in to access history parameters.' )

        if not trans.user_is_admin():
            return trans.fill_template( '/no_access.mako', message='Access denied for non-administrator users !' )

        # Convert URL parameters
        show_deleted  = self._string_as_bool_or_none( show_deleted )
        show_purged   = show_deleted
        show_hidden   = self._string_as_bool_or_none( show_hidden )
        reverse_order = self._string_as_bool_or_none( reverse_order )
        full_screen   = self._string_as_bool_or_none( full_screen )

        # Adapt get_history parameters depending on the user status
        if trans.user_is_admin():
            check_ownership = check_accessible = False

        # Get requested history or current history
        if history_id != None:
            history = self.get_history(trans, history_id, check_ownership=check_ownership, check_accessible=check_accessible )
        else:
            history = trans.get_history( create=False )

        # Get all datasets for current history
        datasets = self.get_history_datasets( trans, history, show_deleted, show_hidden, show_purged )

        # Reverse the datasets list if needed
        if reverse_order:
            datasets.reverse()

        # Browse datasets in the requested order
        for data in datasets:

            # Initializations
            hda = None
            job = None
            tool = None

            # Get the HistoryDatasetAssociation object
            hda = trans.sa_session.query( trans.app.model.HistoryDatasetAssociation ).get( data.id )

            if not hda:
                raise paste.httpexceptions.HTTPRequestRangeNotSatisfiable( "Invalid reference dataset id: %s." % str( data.id ) )

            if hda.creating_job_associations:
                for assoc in hda.creating_job_associations:
                    job = assoc.job
                    break
                if job:
                    # Get the corresponding tool object
                    try:
                        toolbox = self.get_toolbox()
                        tool = toolbox.get_tool( job.tool_id )
                        assert tool is not None, 'Requested tool has not been loaded.'
                    except:
                        pass

            # Associate
            if job != None:
                if job.id not in First_dataset_by_job:
                    First_dataset_by_job[job.id] = data.id
                    Associated_datasets_by_job[job.id] = []

                #if not to_ext:
                    #Associated_datasets_by_job[job.id].append([data.hid, data.display_name(), data.get_file_name()])
                Associated_datasets_by_job[job.id].append([data.hid, data.display_name(), data.get_file_name()])


            # Store all collected datas
            job_objects[data.id] = job
            tool_objects[data.id] = tool

        if to_ext:
            download_name = history.get_display_name() + '.sh'
            trans.response.headers[ "content-disposition" ] = 'attachment; filename="%s"' % ( download_name )
            trans.response.headers[ "content-type" ] = 'application/x-sh'
            return trans.fill_template( "parameters/generate_shell_script.mako", history = history, job_list = job_objects, tool_list = tool_objects, First_dataset_by_job = First_dataset_by_job, Associated_datasets_by_job = Associated_datasets_by_job)

        else:
            return trans.fill_template( "parameters/command_lines.mako", history = history, full_screen = full_screen, job_list = job_objects, tool_list = tool_objects, First_dataset_by_job = First_dataset_by_job, Associated_datasets_by_job = Associated_datasets_by_job)


    @web.expose
    @web.require_login()
    def history_parameters( self, trans, as_xml=False, to_ext=False, show_deleted=False, show_hidden=False, reverse_order=False, history_id=None, full_screen=True, **kwd ):
        """
        Display the current/active history with all its datasets and parameters
        """

        # Initializations
        hda_objects = {}
        job_objects = {}
        tool_objects = {}
        params_objects = {}
        inherit_chain_objects = {}
        datasets_by_job = OrderedDict()
        check_ownership = check_accessible = True

        # Reject non authorized access
        if trans.app.config.require_login and not trans.user:
            return trans.fill_template( '/no_access.mako', message = 'Please log in to access history parameters.' )

        # Adapt get_history parameters depending on the user status
        if trans.user_is_admin():
            check_ownership = check_accessible = False

        # Get requested history or current history
        if history_id != None:
            history = self.get_history(trans, history_id, check_ownership=check_ownership, check_accessible=check_accessible )
        else:
            history = trans.get_history( create=False )

        # Convert URL parameters
        show_deleted = self._string_as_bool_or_none( show_deleted )
        show_purged  = show_deleted
        show_hidden  = self._string_as_bool_or_none( show_hidden )
        reverse_order = self._string_as_bool_or_none( reverse_order )
        full_screen = self._string_as_bool_or_none( full_screen )

        # Get all datasets for current history
        datasets = self.get_history_datasets( trans, history, show_deleted, show_hidden, show_purged )

        # Reverse the datasets list if needed
        if reverse_order:
            datasets.reverse()

        # Browse datasets in the requested order
        for data in datasets:

            # Initializations
            hda = None
            job = None
            tool = None
            params = None
            inherit_chain = None

            # Get the HistoryDatasetAssociation object
            hda = trans.sa_session.query( trans.app.model.HistoryDatasetAssociation ).get( data.id )

            if not hda:
                raise paste.httpexceptions.HTTPRequestRangeNotSatisfiable( "Invalid reference dataset id: %s." % str( data.id ) )

            # Collect inheritance chain
            inherit_chain = hda.source_dataset_chain

            # Get the associated job, if any.
            # If this hda was copied from another, we need to find the job that created the origial dataset association.
            if inherit_chain:
                job_dataset_association, dataset_association_container_name = inherit_chain[-1]
            else:
                job_dataset_association = hda

            if job_dataset_association.creating_job_associations:
                for assoc in job_dataset_association.creating_job_associations:
                    job = assoc.job
                    break
                if job:
                    # Get the corresponding tool object
                    try:
                        toolbox = self.get_toolbox()
                        tool = toolbox.get_tool( job.tool_id )
                        assert tool is not None, 'Requested tool has not been loaded.'

                        # Get the corresponding param object
                        params = job.get_param_values( trans.app )
                    except:
                        pass

            # Associate
            if job != None:
                if job.id not in datasets_by_job:
                    datasets_by_job[job.id] = []

                #~ print ('Append ' + str(data.id) + ' to job ' + str(job.id) + ' for tool ' + str(job.tool_id) + "\n")
                datasets_by_job[job.id].append(data)

            # Store all collected datas
            job_objects[data.id] = job
            tool_objects[data.id] = tool
            params_objects[data.id] = params
            inherit_chain_objects[data.id] = inherit_chain

        # Fill the appropriate template
        if as_xml:
            trans.response.set_content_type( 'text/xml' )

            # Change content disposition to allow user to download the generated XML page
            if to_ext:
                download_name = history.get_display_name() + '.xml'
                trans.response.headers[ "content-disposition" ] = 'attachment; filename="%s"' % ( download_name )

            return trans.fill_template( "parameters/history_parameters_xml.mako",
                                        history = history,
                                        history_hid_id = trans.security.encode_id( history.id ),

                                        show_deleted = show_deleted,
                                        show_hidden = show_hidden,
                                        reverse_order = reverse_order,
                                        over_quota = trans.app.quota_agent.get_percent( trans=trans ) >= 100,

                                        datasets_by_job = datasets_by_job,

                                        job_list = job_objects,
                                        tool_list = tool_objects,
                                        params_list = params_objects,
                                        inherit_chain_list = inherit_chain_objects
                                    )
        else:
            return trans.fill_template( "parameters/history_parameters.mako",
                                        history = history,
                                        history_hid_id = trans.security.encode_id( history.id ),

                                        show_deleted = show_deleted,
                                        show_hidden = show_hidden,
                                        reverse_order = reverse_order,
                                        over_quota = trans.app.quota_agent.get_percent( trans=trans ) >= 100,
                                        full_screen = full_screen,

                                        datasets_by_job = datasets_by_job,

                                        job_list = job_objects,
                                        tool_list = tool_objects,
                                        params_list = params_objects,
                                        inherit_chain_list = inherit_chain_objects
                                    )
