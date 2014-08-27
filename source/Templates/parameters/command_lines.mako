## Imports ##

<% from galaxy.util import nice_size %>

<%inherit file="/base/base_panels.mako"/>
<%namespace name="mod_masthead" file="/webapps/galaxy/galaxy.masthead.mako"/>
<%namespace file="/message.mako" import="render_msg" />

## Default title
<%def name="title()">${_('Galaxy Debug - Get Command Lines')}</%def>




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
## Metadata and Custom Style
##################################################

<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">

</head>

##################################################
## HTML BODY - Page content
##################################################
<body>

<%def name="center_panel()">

    <div class="page-container" style="padding:1px;overflow:auto;height:100%;width:100%">

%if not trans.user_is_admin():

<div id="message-container">${render_msg( "Access denied for non-administrator users !", 'error' )}</div>

%else:


    ## Warnings ##

    %if history.deleted:
        <div class="warningmessagesmall">${_('You are currently viewing a deleted history !')}</div>
    %endif

    %if over_quota:
        <div class="warningmessagesmall">${_('You are over your disk quota !')}</div>
    %endif

    %if not First_dataset_by_job:
        <div class="infomessagesmall" id="emptyHistoryMessage">${_("The selected history does not contains any non imported datasets or is empty")}</div>
    %endif

    ## Context specific actions - Header zone

    %if full_screen == True:
        ## Back button
        <a class="action_button" href="${h.url_for( controller='parameters', action='list')}">Go Back</a>

        ## Refresh button
        <a class="action_button" style="float: right" href="${h.url_for( controller='parameters', action='command_lines', full_screen=full_screen)}">Refresh</a>

        ## Title
        <div class="page_header">Get Command Lines</div>
        <br />
    %endif

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

        %for jobs_ID in First_dataset_by_job:

            <% First_dataset_identifier = First_dataset_by_job[jobs_ID] %>

            <div class="global_tool_block">

                ## Display job data
                <div class="job_info overauto">

                    <table class="tooldata command_lines">
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
                            <tr><td class="fixed_left">Tool identifier:</td><td>${job_list[First_dataset_identifier].tool_id}</td></tr>
                            <tr><td class="fixed_left">Tool version:</td><td>${job_list[First_dataset_identifier].tool_version}</td></tr>
                            %if tool_list[First_dataset_identifier]:
                                <tr><td class="left">Tool file:</td><td>${tool_list[First_dataset_identifier].config_file}</td></tr>
                                <tr><td class="left">Interpreter:</td><td>${tool_list[First_dataset_identifier].interpreter}</td></tr>
                            %else:
                                <tr><td class="left">Tool file:</td><td>This tool has been removed from your Galaxy instance</td></tr>
                                <tr><td class="left">Interpreter:</td><td>This information could not be recovered</td></tr>
                            %endif
                            <tr><td class="fixed_left">Runner:</td><td>${job_list[First_dataset_identifier].job_runner_name}</td></tr>
                            %if job_list[First_dataset_identifier].job_runner_external_id != '':
                                <tr><td class="fixed_left">External job identifier:</td><td>${job_list[First_dataset_identifier].job_runner_external_id}</td></tr>
                            %endif
                            %if tool_list[First_dataset_identifier]:
                                <% data_with_tab = tool_list[First_dataset_identifier].command %>
                                %if data_with_tab[-1] == "\t":
                                    <tr><td class="fixed_left">Command line (XML):</td><td><pre class="with_pad">${data_with_tab[:-1]}</pre></td></tr>
                                %else:
                                    <tr><td class="fixed_left">Command line (XML):</td><td><pre class="with_pad">${data_with_tab}</pre></td></tr>
                                %endif
                            %else:
                                <tr><td class="fixed_left">Command line (XML):</td><td>This information could not be recovered</td></tr>
                            %endif
                            <tr><td class="fixed_left">Command line (System):</td><td>${job_list[First_dataset_identifier].command_line}</td></tr>
                        </tbody>
                    </table>

                </div>

                ## Display list of associated datasets
                <div class="job_info">

                    <table class="tooldata">
                        <thead>
                            <tr>
                                <th colspan="3">Associated datasets (Identifier - Name - Path)</th>
                            </tr>
                        </thead>
                        <tbody>
                            %for dataset in Associated_datasets_by_job[jobs_ID]:
                                <tr>
                                    <td class="fixed_left">Dataset ${dataset[0]}:</td>
                                    <td style="text-align:center">${dataset[1]}</td>
                                    <td style="text-align:center">${dataset[2]}</td>
                                </tr>
                            %endfor
                        </tbody>
                    </table>

                </div>

            </div>

        %endfor

    </div>


%endif


    </div>
</%def>

</body>

</html>


