## Imports ##
<% from galaxy.util import nice_size %>

<%inherit file="/base/base_panels.mako"/>
<%namespace name="mod_masthead" file="/webapps/galaxy/galaxy.masthead.mako"/>
<%namespace file="/message.mako" import="render_msg" />
<%namespace file="function_pack.mako" import="*" />

## Default title
<%def name="title()">${_('Galaxy - History parameters')}</%def>


##################################################
## Galaxy CSS and Javascript imports
##################################################
<%def name="stylesheets()">
    ${h.css( "base", "parameters" )}
    <style>
        .grid td {
            min-width: 100px;
        }
        #center {
            left:5px;
            right:5px;
            }
    </style>
</%def>

## Masthead
<%def name="masthead()">
    <%
        mod_masthead.load(self.active_view);
    %>
</%def>

##################################################
## This is now only necessary for tests
##################################################

%if bool( [ data for data in history.active_datasets if data.state in ['running', 'queued', '', None ] ] ):
<!-- running: do not change this comment, used by TwillTestCase.wait -->
%endif

##################################################
## Galaxy CSS and Javascript imports
##################################################



${h.js(
    "libs/jquery/jquery",
    "galaxy.base",
    "libs/json2",
    "libs/jquery/jstorage"
)}

##################################################
## Metadata and Custom Style
##################################################

<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">


##################################################
## Javascript
##################################################

<script type="text/javascript">

$(function() {
    var historywrapper = $("div.historyItemWrapper");
    init_history_items(historywrapper);

    historywrapper.each( function() {

        // Check to see if the dataset data is cached or needs to be pulled in via objectstore
        $(this).find("a.display").each( function() {
            var history_item = $(this).parents(".historyItem")[0];
            var history_id = history_item.id.split( "-" )[1];
            $(this).click(function() {
                check_transfer_status($(this), history_id);
            });
        });
    });

});

</script>


##################################################
## No Script
##################################################

<noscript>
    <style>.historyItemBody { display: block; }</style>
</noscript>

</head>

##################################################
## HTML BODY - Page content
##################################################
<body>
<%def name="center_panel()">

    <div class="page-container" style="padding:1px;overflow:auto;height:100%;width:100%">

%if not trans.user:

<div id="message-container">${render_msg( "You must be logged in to access this content !", 'error' )}</div>


%else:

<body>
    ## Warnings ##

    %if history.deleted:
        <div class="warningmessagesmall">${_('You are currently viewing a deleted history !')}</div>
    %endif

    %if over_quota:
        <div class="warningmessagesmall">${_('You are over your disk quota !')}</div>
    %endif

    %if not datasets_by_job:
        <div class="infomessagesmall" id="emptyHistoryMessage">${_("The selected history does not contains any non imported datasets or is empty")}</div>
    %endif

    ## Context specific actions - Header zone

    %if full_screen == True:
        ## Back button
        <a class="action_button" href="${h.url_for( controller='parameters', action='list')}">Go Back</a>

        ## Refresh button
        <a class="action_button" style="float: right" href="${h.url_for( controller='parameters', action='history_parameters', show_hidden=show_hidden, show_deleted=show_deleted, reverse_order=reverse_order, full_screen=full_screen)}">Refresh</a>

        ## Title
        <div class="page_header">History parameters</div>
        <br />
    %endif

    ## Hide and show switches ##

    <%
        # Build url
        if show_deleted:
            del_url = h.url_for( controller='parameters', action='history_parameters', show_deleted=False, show_hidden=show_hidden, reverse_order=reverse_order, full_screen=full_screen, history_id=history_hid_id)
        else:
            del_url = h.url_for( controller='parameters', action='history_parameters', show_deleted=True, show_hidden=show_hidden, reverse_order=reverse_order, full_screen=full_screen, history_id=history_hid_id)

        if show_hidden:
            hid_url = h.url_for( controller='parameters', action='history_parameters', show_hidden=False, show_deleted=show_deleted, reverse_order=reverse_order, full_screen=full_screen, history_id=history_hid_id)
        else:
            hid_url = h.url_for( controller='parameters', action='history_parameters', show_hidden=True, show_deleted=show_deleted, reverse_order=reverse_order, full_screen=full_screen, history_id=history_hid_id)
    %>

    %if show_deleted:
        <div class="show_or_hide">
            <a class="action_button" href="${del_url}">${_('Hide deleted datasets')}</a>
        </div>
    %else:
        <div class="show_or_hide">
            <a class="action_button" href="${del_url}">${_('Show deleted datasets')}</a>
        </div>
    %endif

    %if show_hidden:
        <div class="show_or_hide">
            <a class="action_button" href="${hid_url}">${_('Hide hidden datasets')}</a>
        </div>
    %else:
        <div class="show_or_hide">
            <a class="action_button" href="${hid_url}">${_('Show hidden datasets')}</a>
        </div>
    %endif

    <br />

    ## History summary ##

    <h1>${history.get_display_name()}</h1>

    <div class="history_info">This history consumes the following amount of storage space: ${history.get_disk_size(nice_size=True)}</div>

    %if history.published:
        <div class="history_info">This history is published</div>
    %endif

    <div class="history_info" style="margin-top: 15px">Creation date: ${history.create_time.isoformat(' ')}</div>
    <div class="history_info" style="margin-bottom: 25px">Last update: ${history.update_time.isoformat(' ')}</div>

    ## Display parameters by job/tool (Ordered from Oldest to newest) ##
    <div>
        %for jobs_ID in datasets_by_job:

            <% First_dataset_identifier = datasets_by_job[jobs_ID][0].id %>

            <div class="global_tool_block">

                ## Display job data (only one time)
                <div class="job_info">

                    <table class="tooldata">
                        <thead>
                            <tr><th colspan="2" style="font-size: 120%;">
                                % if tool_list[First_dataset_identifier]:
                                    ${tool_list[First_dataset_identifier].name}
                                % else:
                                    Unknown Tool / Removed Tool
                                % endif
                            </th></tr>
                        </thead>
                        <tbody>
                            <tr><td class="left">Tool identifier:</td><td>${job_list[First_dataset_identifier].tool_id}</td></tr>
                            <tr><td class="left">Tool version:</td><td>${job_list[First_dataset_identifier].tool_version}</td></tr>
                            %if trans.user_is_admin():
                                %if tool_list[First_dataset_identifier]:
                                    <tr><td class="left">Tool file:</td><td>${tool_list[First_dataset_identifier].config_file}</td></tr>
                                    <tr><td class="left">Interpreter:</td><td>${tool_list[First_dataset_identifier].interpreter}</td></tr>
                                %else:
                                    <tr><td class="left">Tool file:</td><td>This tool has been removed from your Galaxy instance</td></tr>
                                    <tr><td class="left">Interpreter:</td><td>This information could not be recovered</td></tr>
                                %endif
                                <tr><td class="left">Runner:</td><td>${job_list[First_dataset_identifier].job_runner_name}</td></tr>
                                %if job_list[First_dataset_identifier].job_runner_external_id != '':
                                    <tr><td class="left">External job identifier:</td><td>${job_list[First_dataset_identifier].job_runner_external_id}</td></tr>
                                %endif
                                <tr><td class="left">Command line (System):</td><td>${job_list[First_dataset_identifier].command_line}</td></tr>
                            %endif
                            <tr><td class="left">Job state:</td><td>${job_list[First_dataset_identifier].state}</td></tr>
                            %if job_list[First_dataset_identifier].exit_code != '':
                                <tr><td class="left">Exit code:</td><td>${job_list[First_dataset_identifier].exit_code}</td></tr>
                            %endif
                        </tbody>
                    </table>

                </div>

                ## Display parameters (only one time)
                <div class="job_info">

                    <table class="tooldata">
                        <thead>
                            <tr>
                                <th colspan="2">Selected Parameters</th>
                            </tr>
                        </thead>
                        <tbody>
                            % if params_list[First_dataset_identifier] and tool_list[First_dataset_identifier]:
                                ${ recursive_params(tool_list[First_dataset_identifier].inputs, params_list[First_dataset_identifier], depth=1) }
                            % else:
                                <tr><td colspan="2">No parameters / Unrecoverable parameters</td></tr>
                            % endif

                        </tbody>
                    </table>

                </div>

                ## Display all datasets
                %for data in datasets_by_job[jobs_ID]:

                    %if data.visible or show_hidden:
                        ${render_dataset( data )}
                    %endif

                %endfor

            </div>

        %endfor

    </div>


%endif

    </div>
</%def>

</body>


</html>
