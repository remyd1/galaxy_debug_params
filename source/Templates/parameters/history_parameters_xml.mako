## -*- coding: utf-8 -*-
<%
    #############
    ## Methods ##
    #############
    ###################################
    ## Generate tag for history data ##
    def get_history_tags(history, XML_elements):
        XML_elements.append([0, 'history', 'Container_tag'])
        XML_elements.append([4, 'name', history.get_display_name()])
        XML_elements.append([4, 'disk_space', history.get_disk_size(nice_size=True)])
        if history.published:
            XML_elements.append([4, 'published' , 'yes'])
        else:
            XML_elements.append([4, 'published', 'no'])
        XML_elements.append([4, 'creation_date', history.create_time.isoformat(' ')])
        XML_elements.append([4, 'update_date', history.update_time.isoformat(' ')])
        XML_elements.append([0, '/history', 'Container_tag'])


    ################################
    ## Generate tags for all jobs ##
    def get_job_tags(datasets_by_job, job_list, tool_list, params_list, inherit_chain_list, is_admin, app_obj, XML_elements):
        XML_elements.append([0, 'jobs', 'Container_tag'])

        for jobs_ID in datasets_by_job:
            XML_elements.append([4, 'job', 'Container_tag'])

            ## Tools tags
            First_dataset_identifier = datasets_by_job[jobs_ID][0].id
            get_tool_tags(job_list[First_dataset_identifier], tool_list[First_dataset_identifier], is_admin, XML_elements)

            ## Parameters tags
            if params_list[First_dataset_identifier] and tool_list[First_dataset_identifier]:
                XML_elements.append([8, 'parameters', 'Container_tag'])
                get_param_tags(tool_list[First_dataset_identifier].inputs, params_list[First_dataset_identifier], app_obj, XML_elements)
                XML_elements.append([8, '/parameters', 'Container_tag'])
            else:
                XML_elements.append([8, 'parameters', 'No parameters / Unrecoverable parameters'])

            ## Datasets tags
            XML_elements.append([8, 'datasets', 'Container_tag'])
            for data in datasets_by_job[jobs_ID]:
                get_dataset_tags(data, job_list[data.id], is_admin, app_obj, XML_elements)
            XML_elements.append([8, '/datasets', 'Container_tag'])

            XML_elements.append([4, '/job', 'Container_tag'])

        XML_elements.append([0, '/jobs', 'Container_tag'])

    ####################################
    ## Generate tags for a given tool ##
    def get_tool_tags(job_data, tool_data, is_admin, XML_elements):
        XML_elements.append([8, 'tool_data', 'Container_tag'])

        if tool_data:
            XML_elements.append([12, 'name', tool_data.name])
        else:
            XML_elements.append([12, 'name', 'Unknown Tool / Removed Tool'])

        XML_elements.append([12, 'identifier', job_data.tool_id])
        XML_elements.append([12, 'version', job_data.tool_version])
        if is_admin:
            if tool_data:
                XML_elements.append([12, 'interpreter', tool_data.interpreter])
                XML_elements.append([12, 'runner', job_data.job_runner_name])
            if job_data.job_runner_external_id:
                XML_elements.append([12, 'external_job_identifier', job_data.job_runner_external_id])
            clean_command_line = " ".join(job_data.command_line.replace("\t", '').split())
            ### We need a clean Xml file without HTML special chars
            ### However, > is a redirection, & and could be also used
            ### in the command line...
            ## clean_command_line = html_escape(clean_command_line)
            XML_elements.append([12, 'command_line', clean_command_line])

        XML_elements.append([12, 'state', job_data.state])
        if job_data.exit_code:
            XML_elements.append([12, 'exit_code', job_data.exit_code])

        XML_elements.append([8, '/tool_data', 'Container_tag'])


    ##############################################
    ## Generate tags for params of a given tool ##
    def get_param_tags(input_params, param_values, app_obj, XML_elements):
        for input_index, input in enumerate( input_params.itervalues() ):
            if input.name in param_values:
                if input.type == "repeat":
                    for i in range( len(param_values[input.name]) ):
                        get_param_tags(input.inputs, param_values[input.name][i], app_obj, XML_elements)
                elif input.type == "conditional":
                    current_case = param_values[input.name]['__current_case__']
                    XML_elements.append([12, 'param', input.cases[current_case].value, 'name="' + input.test_param.label + '"'])
                    get_param_tags(input.cases[current_case].inputs, param_values[input.name], app_obj, XML_elements)

                elif getattr(input, "label", None):
                    XML_elements.append([12, 'param', str(input.value_to_display_text(param_values[input.name], app_obj)).replace("\n",' '), 'name="' + input.label + '"'])
            else:
                ## Parameter does not have a stored value.
                if input.type == "conditional":
                    label = input.test_param.label
                else:
                    label = input.label
                XML_elements.append([12, 'param', 'not used', 'name="' + label + '"'])


    #############################################################
    ## Generate tags for each datasets related to a given tool ##
    def get_dataset_tags(data, job_data, is_admin, app_obj, XML_elements):

        if data.state in ['no state','',None]:
            data_state = "queued"
        else:
            data_state = data.state
        current_user_roles = trans.get_current_user_roles()

        XML_elements.append([12, 'dataset', 'Container_tag', 'state="' + data_state + '"'])

        ## Check access right
        if not is_admin and not app_obj.security_agent.can_access_dataset( current_user_roles, data.dataset ):
            XML_elements.append([16, 'error', 'You do not have permission to view this dataset !'])
        else:
            ## Check if the dataset has been deleted and display a warning message if needed
            if data.deleted or data.purged or data.dataset.purged:
                if data.dataset.purged or data.purged:
                    XML_elements.append([16, 'warning', 'This dataset has been deleted and removed from disk'])
                else:
                    XML_elements.append([16, 'warning', 'This dataset has been deleted'])

            ## Display a warning message for hidden datasets
            if data.visible is False:
                XML_elements.append([16, 'warning', 'This dataset has been hidden'])

            ## Generic informations (Not state related)
            dname = html_escape(data.display_name())
            XML_elements.append([16, 'name', dname])
            XML_elements.append([16, 'identifier', data.hid])
            XML_elements.append([16, 'file_size', data.get_size(nice_size=True)])
            XML_elements.append([16, 'file_size_in_bytes', data.get_size(nice_size=False)])

            ## Dataset informations depending on the sate ##

            ## Upload state
            if data_state == "upload":
                XML_elements.append([16, 'info', 'Dataset is uploading'])

            ## Queued state
            elif data_state == "queued":
                XML_elements.append([16, 'info', 'Job is waiting to run'])

            ## Paused state
            elif data_state == "paused":
                XML_elements.append([16, 'info', 'Job is currently paused'])

            ## Running state
            elif data_state == "running":
                XML_elements.append([16, 'info', 'Job is currently running'])

            ## Error state
            elif data_state == "error":
                XML_elements.append([16, 'warning', 'An error occurred running this job'])
                if job_data.stderr:
                    list_error = filter(None, job_data.stderr.split("\n"))
                    XML_elements.append([16, 'error_messages', 'Container_tag'])
                    for error_line in list_error:
                        if type( error_line ) is not unicode:
                            error_line = unicode( error_line, 'utf-8')
                        error_line = html_escape(error_line)
                        XML_elements.append([20, 'error_line', error_line])
                    XML_elements.append([16, '/error_messages', 'Container_tag'])

            ## Discarded state
            elif data_state == "discarded":
                XML_elements.append([16, 'info', 'The job creating this dataset was cancelled before completion'])

            ## Setting metadata state
            elif data_state == 'setting_metadata':
                XML_elements.append([16, 'info', 'Metadata is being Auto-Detected'])

            ## Empty state
            elif data_state == "empty":
                XML_elements.append([16, 'info', 'No data - Empty'])

            ## OK state
            elif data_state in [ "ok", "failed_metadata" ]:

                if data_state == "failed_metadata":
                    XML_elements.append([16, 'warning', 'An error occurred setting the metadata for this dataset'])

                ## Display basic common informations
                XML_elements.append([16, 'creation_time', data.create_time.isoformat(' ')])
                XML_elements.append([16, 'file_format', data.ext])
                XML_elements.append([16, 'mime_type', data.get_mime()])
                if is_admin or app_obj.config.expose_dataset_path:
                    XML_elements.append([16, 'full_path', data.get_file_name()])

                ## Display specific metadata
                all_metadata = data.get_metadata()

                XML_elements.append([16, 'nb_lines', all_metadata.get('data_lines')])
                if all_metadata.get('sequences') != None:
                    XML_elements.append([16, 'nb_sequences', all_metadata.get('sequences')])

                ## Display info
                if data.display_info():
                    # Get a clean list of information (additional informations, error messages, etc)
                    list_info = filter(None, data.display_info().split("<br/>"))
                    XML_elements.append([16, 'additional_datas', 'Container_tag'])
                    for info in list_info:
                        XML_elements.append([20, 'data', info])
                    XML_elements.append([16, '/additional_datas', 'Container_tag'])

                ## Display one line inheritance chain
                if inherit_chain_list[data.id]:
                    heritage = []

                    for dep in reversed(inherit_chain_list[data.id]):
                        if dep[1] == "(Data Library)":
                            heritage.append(["Data library", None, None])
                        else:
                            heritage.append(["History", dep[1], dep[0].name])

                    XML_elements.append([16, 'inheritance_chain', 'Container_tag'])
                    for member in heritage:
                        if member[0] == "Data library":
                            XML_elements.append([20, 'chain_link', '', 'source="' + member[0] + '"'])
                        else:
                            XML_elements.append([20, 'chain_link', '', 'source="' + member[0] + '" source_name="' + member[1] + '" dataset_name="' + member[2] + '"'])
                    XML_elements.append([16, '/inheritance_chain', 'Container_tag'])

            ## Unknown state
            else:
                XML_elements.append([16, 'error', _('Error: unknown dataset state "%s".') % data_state])

        XML_elements.append([12, '/dataset', 'Container_tag'])

    def html_escape(text):
        """Produce entities within text."""
        html_escape_table = {"&": "&amp;",">": "&gt;","<": "&lt;"}
        return "".join(html_escape_table.get(c,c) for c in text)

    ##########
    ## MAIN ##
    ##########

    
    ## Create an ordered dict to store all XML tags (as string) and indentation level
    XML_elements = list()

    ## Check global datas
    if history.deleted:
        XML_elements.append([0, 'warning', 'You are currently viewing a deleted history'])

    if over_quota:
        XML_elements.append([0, 'warning', 'You are over your disk quota'])

    if not datasets_by_job:
        XML_elements.append([0, 'info', 'The selected history does not contains any non imported datasets or is empty'])

    ## Collect informations about the selected history
    get_history_tags(history, XML_elements)

    ## Collect informations about all jobs
    get_job_tags(datasets_by_job, job_list, tool_list, params_list, inherit_chain_list, trans.user_is_admin(), trans.app, XML_elements)

%>\
\
## Method to print well indented XML file in a mako template
<%def name="print_tags( tags )">
 %for element in tags:
  %if element[2] == 'Container_tag':
   %if len(element) > 3:
    ${" " * element[0]}<${element[1]} ${element[3]}>
   %else:
    ${" " * element[0]}<${element[1]}>
   %endif
  %else:
   %if len(element) > 3:
    ${" " * element[0]}<${element[1]} ${element[3]}>${element[2]}</${element[1]}>
   %else:
    ${" " * element[0]}<${element[1]}>${element[2]}</${element[1]}>
   %endif
  %endif
 %endfor
</%def>\
## XML body
<%text><?xml version="1.0" encoding="UTF-8" ?></%text>
<history_parameters>
%if not trans.user:
    <error>You must be logged in to acces this content</error>
%else:
  ${ print_tags( tags=XML_elements ) }
%endif
</history_parameters>