<%inherit file="/base/base_panels.mako"/>

## Default title
<%def name="title()">Galaxy</%def>

<%def name="javascripts()">
${parent.javascripts()}

<!-- quota meter -->
${h.templates( "helpers-common-templates" )}
${h.js( "mvc/base-mvc", "utils/localization", "mvc/user/user-model", "mvc/user/user-quotameter" )}
</%def>

<%def name="get_user_json()">
<%
    """Bootstrapping user API JSON"""
    #TODO: move into common location (poss. BaseController)
    if trans.user:
        user_dict = trans.user.to_dict( view='element', value_mapper={ 'id': trans.security.encode_id,
                                                                             'total_disk_usage': float } )
        ##TODO: move these into to_dict
        user_dict['quota_percent'] = trans.app.quota_agent.get_percent( trans=trans )
        user_dict['tags_used'] = trans.webapp.controllers[ 'tag' ].get_user_tags_used( trans )
    else:
        usage = 0
        percent = None
        try:
            usage = trans.app.quota_agent.get_usage( trans, history=trans.history )
            percent = trans.app.quota_agent.get_percent( trans=trans, usage=usage )
        except AssertionError, assertion:
            # no history for quota_agent.get_usage assertion
            pass
        user_dict = {
            'total_disk_usage'      : int( usage ),
            'nice_total_disk_usage' : util.nice_size( usage ),
            'quota_percent'         : percent
        }

%>
${h.to_json_string( user_dict )}
</%def>

<%def name="late_javascripts()">
${parent.late_javascripts()}
<script type="text/javascript">

    // start a Galaxy namespace for objects created
    window.Galaxy = window.Galaxy || {};

    // set up the quota meter (And fetch the current user data from trans)
    Galaxy.currUser = new User( ${get_user_json()} );
    Galaxy.quotaMeter = new UserQuotaMeter({
        model   : Galaxy.currUser,
        el      : $( document ).find( '.quota-meter-container' )
    }).render();

</script>
</%def>

## Masthead
<%def name="masthead()">

    ## Tab area, fills entire width
    <div style="position: relative; right: -50%; float: left;">
    <div style="display: block; position: relative; right: 50%;">

    <ul class="nav navbar-nav" border="0" cellspacing="0">
    
    <%def name="tab( id, display, href, onclick=False, target='_parent', visible=True, extra_class='', menu_options=None )">
        ## Create a tab at the top of the panels. menu_options is a list of 2-elements lists of [name, link]
        ## that are options in the menu.
    
        <%
        cls = ""
        a_cls = ""
        extra = ""
        if extra_class:
            cls += " " + extra_class
        if self.active_view == id:
            cls += " active"
        if menu_options:
            cls += " dropdown"
            a_cls += " dropdown-toggle"
            extra = "<b class='caret'></b>"
        style = ""
        if not visible:
            style = "display: none;"
        %>
        <li class="${cls}" style="${style}">
            %if href:
                <a class="${a_cls}" data-toggle="dropdown" target="${target}" href="${href}">${display}${extra}</a>
            %else:
                <a class="${a_cls}" data-toggle="dropdown">${display}${extra}</a>
            %endif
            %if menu_options:
                <ul class="dropdown-menu">
                    %for menu_item in menu_options:
                        %if not menu_item:
                            <li class="divider"></li>
                        %else:
                            <li>
                            %if len ( menu_item ) == 1:
                                ${menu_item[0]}
                            %elif len ( menu_item ) == 2:
                                <% name, link = menu_item %>
                                %if onclick:
                                    <a href="${link}" onclick="Galaxy.frame_manager.frame_new({title: '${name}', type: 'url', content: '${link}'}); return false;">${name}</a>
                                %else:
                                    <a href="${link}">${name}</a>
                                %endif
                            %else:
                                <% name, link, target = menu_item %>
                                <a target="${target}" href="${link}">${name}</a>
                            %endif
                            </li>
                        %endif
                    %endfor
                </ul>
            %endif
        </li>
    </%def>

    ## Analyze data tab.
    ${tab( "analysis", _("Analyze Data"), h.url_for( controller='/root', action='index' ) )}
    
    ## Workflow tab.
    ${tab( "workflow", _("Workflow"), h.url_for( controller='/workflow', action='index' ) )}

    ## 'Shared Items' or Libraries tab.
    <%
        menu_options = [ 
                        [ _('Data Libraries'), h.url_for( controller='/library', action='index') ],
                        None,
                        [ _('Published Histories'), h.url_for( controller='/history', action='list_published' ) ],
                        [ _('Published Workflows'), h.url_for( controller='/workflow', action='list_published' ) ],
                        [ _('Published Visualizations'), h.url_for( controller='/visualization', action='list_published' ) ],
                        [ _('Published Pages'), h.url_for( controller='/page', action='list_published' ) ]
                       ] 
        tab( "shared", _("Shared Data"), h.url_for( controller='/library', action='index'), menu_options=menu_options )
    %>

    
    ## Parameters tab
    <%
        menu_options = [
                        [ _('Accessible histories'), h.url_for( controller='/parameters', action='list'), "galaxy_main" ],
                        None,
                        [ _('Display history parameters'), h.url_for( controller='/parameters', action='history_parameters', full_screen='False'), "galaxy_main" ],
                        [ _('Display history parameters - Reverse order'), h.url_for( controller='/parameters', action='history_parameters', full_screen='False', reverse_order='True'), "galaxy_main" ],
                        [ _('History parameters in XML format (New tab)'), h.url_for( controller='/parameters', action='history_parameters', as_xml='True'), "_blank" ],
                        [ _('Download parameters'), h.url_for( controller='/parameters', action='history_parameters', as_xml='True', to_ext='True'), "_blank" ],
                    ]
        tab( "parameters", _("Parameters"), None, menu_options=menu_options, visible=( trans.user ) )
    %>
    
    ## Debug tab
    <%
        menu_options = [
                        [ _('Accessible histories'), h.url_for( controller='/parameters', action='list'), "galaxy_main" ],
                        None,
                        [ _('Debug command lines'), h.url_for( controller='/parameters', action='command_lines', full_screen='False'), "galaxy_main" ],
                        [ _('Debug command lines - Reverse order'), h.url_for( controller='/parameters', action='command_lines', full_screen='False', reverse_order='True'), "galaxy_main" ],
                        None,
                        [ _('Generate shell script'), h.url_for( controller='/parameters', action='command_lines', full_screen='False', to_ext='True'), "_blank" ]
                    ]
        tab( "debug", _("Debug"), None, menu_options=menu_options, visible=( trans.user and app.config.is_admin_user( trans.user ) ) )
    %>
   
 
    ## Lab menu.
    <%
        menu_options = [
                         [ _('Sequencing Requests'), h.url_for( controller='/requests', action='index' ) ],
                         [ _('Find Samples'), h.url_for( controller='/requests', action='find_samples_index' ) ],
                         [ _('Help'), app.config.get( "lims_doc_url", "http://main.g2.bx.psu.edu/u/rkchak/p/sts" ), "galaxy_main" ]
                       ]
        tab( "lab", "Lab", None, menu_options=menu_options, visible=( trans.user and ( trans.user.requests or trans.app.security_agent.get_accessible_request_types( trans, trans.user ) ) ) )
    %>


                                    
    ## Visualization menu.
    <%
        menu_options = [
                         [_('New Track Browser'), h.url_for( controller='/visualization', action='trackster' )],
                         [_('Saved Visualizations'), h.url_for( controller='/visualization', action='list' )]
                       ]
        tab( "visualization", _("Visualization"), h.url_for( controller='/visualization', action='list' ), menu_options=menu_options, onclick=True )
    %>

    ## Cloud menu.
    %if app.config.get_bool( 'enable_cloud_launch', False ):
        <%
            menu_options = [
                             [_('New Cloud Cluster'), h.url_for( controller='/cloudlaunch', action='index' ) ],
                           ]
            tab( "cloud", _("Cloud"), h.url_for( controller='/cloudlaunch', action='index'), menu_options=menu_options )
        %>
    %endif

    ## Admin tab.
    ${tab( "admin", "Admin", h.url_for( controller='/admin', action='index' ), extra_class="admin-only", visible=( trans.user and app.config.is_admin_user( trans.user ) ) )}
    
    ## Help tab.
    <%
        menu_options = []
        if app.config.biostar_url:
            menu_options = [ [_('Galaxy Q&A Site'), h.url_for( controller='biostar', action='biostar_redirect', biostar_action='show/tag/galaxy' ), "_blank" ],
                             [_('Ask a question'), h.url_for( controller='biostar', action='biostar_question_redirect' ), "_blank" ] ]
        menu_options.extend( [
            [_('Support'), app.config.get( "support_url", "http://wiki.galaxyproject.org/Support" ), "_blank" ],
            [_('Search'), app.config.get( "search_url", "http://galaxyproject.org/search/usegalaxy/" ), "_blank" ],
            [_('Mailing Lists'), app.config.get( "mailing_lists", "http://wiki.galaxyproject.org/MailingLists" ), "_blank" ],
            [_('Videos'), app.config.get( "videos_url", "http://vimeo.com/galaxyproject" ), "_blank" ],
            [_('Wiki'), app.config.get( "wiki_url", "http://galaxyproject.org/" ), "_blank" ],
            [_('How to Cite Galaxy'), app.config.get( "citation_url", "http://wiki.galaxyproject.org/CitingGalaxy" ), "_blank" ]
        ] )
        if app.config.get( 'terms_url', None ) is not None:
            menu_options.append( [_('Terms and Conditions'), app.config.get( 'terms_url', None ), '_blank'] )
        tab( "help", _("Help"), None, menu_options=menu_options )
    %>
    
    ## User tabs.
    <%  
        # Menu for user who is not logged in.
        menu_options = [ [ _("Login"), h.url_for( controller='/user', action='login' ), "galaxy_main" ] ]
        if app.config.allow_user_creation:
            menu_options.append( [ _("Register"), h.url_for( controller='/user', action='create', cntrller='user' ), "galaxy_main" ] ) 
        extra_class = "loggedout-only"
        visible = ( trans.user == None )
        tab( "user", _("User"), None, visible=visible, menu_options=menu_options )
        
        # Menu for user who is logged in.
        if trans.user:
            email = trans.user.email
        else:
            email = ""
        menu_options = [ [ '<a>Logged in as <span id="user-email">%s</span></a>' %  email ] ]
        if app.config.use_remote_user:
            if app.config.remote_user_logout_href:
                menu_options.append( [ _('Logout'), app.config.remote_user_logout_href, "_top" ] )
        else:
            menu_options.append( [ _('Preferences'), h.url_for( controller='/user', action='index', cntrller='user' ), "galaxy_main" ] )
            menu_options.append( [ 'Custom Builds', h.url_for( controller='/user', action='dbkeys' ), "galaxy_main" ] )
            logout_url = h.url_for( controller='/user', action='logout' )
            menu_options.append( [ 'Logout', logout_url, "_top" ] )
            menu_options.append( None )
        menu_options.append( [ _('Saved Histories'), h.url_for( controller='/history', action='list' ), "galaxy_main" ] )
        menu_options.append( [ _('Saved Datasets'), h.url_for( controller='/dataset', action='list' ), "galaxy_main" ] )
        menu_options.append( [ _('Saved Pages'), h.url_for( controller='/page', action='list' ), "_top" ] )
        menu_options.append( [ _('API Keys'), h.url_for( controller='/user', action='api_keys', cntrller='user' ), "galaxy_main" ] )
        if app.config.use_remote_user:
            menu_options.append( [ _('Public Name'), h.url_for( controller='/user', action='edit_username', cntrller='user' ), "galaxy_main" ] )

        extra_class = "loggedin-only"
        visible = ( trans.user != None )
        tab( "user", "User", None, visible=visible, menu_options=menu_options )
    %>
    
    ## </tr>
    ## </table>
    </ul>

    </div>
    </div>
    
    ## Logo, layered over tabs to be clickable
    <div class="navbar-brand">
        <a href="${h.url_for( app.config.get( 'logo_url', '/' ) )}">
        <img border="0" src="${h.url_for('/static/images/galaxyIcon_noText.png')}">
        Galaxy
        %if app.config.brand:
            <span>/ ${app.config.brand}</span>
        %endif
        </a>
    </div>

    <div class="quota-meter-container"></div>

</%def>
