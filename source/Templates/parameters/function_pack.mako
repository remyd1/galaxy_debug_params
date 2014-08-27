<% _=n_ %>

## Recursive function to display tool parameters
<%def name="recursive_params( input_params, param_values, depth=1 )">
	%for input_index, input in enumerate( input_params.itervalues() ):
		%if input.name in param_values:
			%if input.type == "repeat":
				%for i in range( len(param_values[input.name]) ):
					${ recursive_params(input.inputs, param_values[input.name][i], depth=depth+1) }
				%endfor
			%elif input.type == "conditional":
				<% current_case = param_values[input.name]['__current_case__'] %>
				<tr>
					${ recursive_indent( text=input.test_param.label, depth=depth )}
					<!-- Get the value of the current Conditonal parameter -->
					<td class="param_value">${input.cases[current_case].value}</td>
				</tr>
				${ recursive_params(input.cases[current_case].inputs, param_values[input.name], depth=depth+1) }
			%elif getattr(input, "label", None):
				<tr>
					${recursive_indent( text=input.label, depth=depth )}
					<td class="param_value">${input.value_to_display_text(param_values[input.name], trans.app)}</td>
				</tr>
			%endif
		%else:
			## Parameter does not have a stored value.
			<tr>
				<%
					# Get parameter label.  
					if input.type == "conditional":
						label = input.test_param.label
					else:
						label = input.label
				%>
				${recursive_indent( text=label, depth=depth )}
				<td><em>not used (parameter was added after this job was run)</em></td>
			</tr>
		%endif
		
	%endfor
</%def>


## Function to add an indentation depending on the depth in a <tr>
<%def name="recursive_indent( text, depth )">
	<td style="padding-left: ${ depth  * 10 }px;">
		${text}
	</td> 
</%def>


## Function to display the element of an inheritance chain in a table
<%def name="indent_element( text, depth )">
	<td style="padding-left: ${ depth  * 15 }px;">
		%if depth != 0:
			<span style="font-size: 15px;">&rArr;</span> ${text}
		%else:
			${text}
		%endif
	</td> 
</%def>


## Function to genenerate download links/buttons
<%def name="render_download_links( data, dataset_id )">
	<%
		from galaxy.datatypes.metadata import FileParameter
	%>
	%if not data.purged:
		## Check for downloadable metadata files
		<% meta_files = [ k for k in data.metadata.spec.keys() if isinstance( data.metadata.spec[k].param, FileParameter ) ] %>
		%if meta_files:
			<div popupmenu="dataset-${dataset_id}-popup">
				<a class="action-button" href="${h.url_for( controller='dataset', action='display', dataset_id=dataset_id, \
					to_ext=data.ext )}">Download Dataset</a>
				<a>Additional Files</a>
			%for file_type in meta_files:
				<a class="action-button" href="${h.url_for( controller='/dataset', action='get_metadata_file', \
					hda_id=dataset_id, metadata_name=file_type )}">Download ${file_type}</a>
			%endfor
			</div>
			<div style="float:left;" class="menubutton split popup" id="dataset-${dataset_id}-popup">
		%endif
		<a href="${h.url_for( controller='/dataset', action='display', dataset_id=dataset_id, to_ext=data.ext )}" title='${_("Download dataset")}' class="icon-button disk tooltip" style="margin-right:5px"></a>
		%if meta_files:
			</div>
		%endif
	%endif
</%def>


## Function to render a dataset depending on its state
<%def name="render_dataset( data )">
	
	## Pure Python code block
	<%
		dataset_id = trans.security.encode_id( data.id )

		if data.state in ['no state','',None]:
			data_state = "queued"
		else:
			data_state = data.state
		current_user_roles = trans.get_current_user_roles()
		can_edit = not ( data.deleted or data.purged )
	%>
	
	## Check access right
	
	%if not trans.user_is_admin() and not trans.app.security_agent.can_access_dataset( current_user_roles, data.dataset ):
		<div class="historyItemWrapper historyItem historyItem-${data_state} historyItem-noPermission" id="historyItem-${dataset_id}" style="border: 2px solid purple;">
	%else:
		<div class="historyItemWrapper related_datasets historyItem historyItem-${data_state}" id="historyItem-${dataset_id}">
	%endif
	
	## Check if the dataset has been deleted and display a warning message if needed
	
	%if data.deleted or data.purged or data.dataset.purged:
		<div class="warningmessagesmall"><strong>
			%if data.dataset.purged or data.purged:
				This dataset has been deleted and removed from disk.
			%else:
				This dataset has been deleted. 
			%endif
		</strong></div>
	%endif

	## Display a warning message for hidden datasets
	
	%if data.visible is False:
		<div class="warningmessagesmall">
			<strong>This dataset has been hidden. Click <a href="${h.url_for( controller='dataset', action='unhide', dataset_id=dataset_id )}" class="historyItemUnhide" id="historyItemUnhider-${dataset_id}" target="galaxy_history">here</a> to unhide.</strong>
		</div>
	%endif

	## Header row for history items (name, state, action buttons)
	
	<div style="overflow: hidden" class="historyItemTitleBar">
		
		<div class="historyItemButtons">
		
			## Special case for dataset in upload state
			%if data_state == "upload":
				## TODO: Make these CSS, just adding a "disabled" class to the normal
				## links should be enough. However the number of datasets being uploaded
				## at a time is usually small so the impact of these images is also small.
				<span title='${_("Display Data")}' class='icon-button display_disabled tooltip'></span>
			
			## Special case for datasets in error state
			%elif data_state == "error":
				<a href="${h.url_for( controller='dataset', action='errors', id=data.id )}" target="_blank" title="View errors (New tab)" class="icon-button bug tooltip"></a>
				
			%else:
				<% display_url = h.url_for( controller='dataset', action='display', dataset_id=dataset_id, preview=True, filename='' ) %>
				
				%if data.has_data():
					${render_download_links( data, dataset_id )}
				%endif
				
				%if data.purged:
					<span class="icon-button display_disabled tooltip" title="Cannot display datasets removed from disk"></span>
				%else:
					<a class="icon-button display tooltip" dataset_id="${dataset_id}" title='${_("Preview dataset (New tab)")}' href="${display_url}" target="_blank" ></a>
				%endif
			%endif

		</div>
		
		## drop down block with icon
		## Hack, do it in css
		%if data_state == "paused":
			<span class="ficon pause"></span>
		%else:
			<span class="state-icon"></span>
		%endif
		<span class="historyItemTitle">${data.hid}: ${data.display_name()}</span>
		
	</div>
	
	
	## Body for history items, extra info and actions, data "peek"
	
	<div id="info${data.id}" class="historyItemBody">
		## Check access rights
		%if not trans.user_is_admin() and not trans.app.security_agent.can_access_dataset( current_user_roles, data.dataset ):
			<div>You do not have permission to view this dataset.</div>
			
		## Upload state
		%elif data_state == "upload":
			<div>Dataset is uploading</div>
			
		## Queued state
		%elif data_state == "queued":
			<div>${_('Job is waiting to run')}</div>
			
		## Paused state
		%elif data_state == "paused":
			<div>${_('Job is currently paused:')} <i>${data.display_info().strip().rstrip('.')}.</i>  ${_('Use the history menu to resume.')}</div>
		
		## Running state
		%elif data_state == "running":
			<div>${_('Job is currently running')}</div>
			
		## Error state
		%elif data_state == "error":
			%if not data.purged:
				<div>${data.get_size( nice_size=True )}</div>
			%endif
			<div>
				An error occurred running this job: <i>${data.display_info().strip()}</i>
			</div>
			
		## Discarded state
		%elif data_state == "discarded":
			<div>
				The job creating this dataset was cancelled before completion.
			</div>
			
		## Setting metadata state
		%elif data_state == 'setting_metadata':
			<div>${_('Metadata is being Auto-Detected.')}</div>
			
		## Empty state
		%elif data_state == "empty":
			<div>${_('No data: ')}<i>${data.display_info()}</i></div>
			
		## OK state
		%elif data_state in [ "ok", "failed_metadata" ]:
			
			%if data_state == "failed_metadata":
				<div class="warningmessagesmall" style="margin: 4px 0 4px 0">
					An error occurred setting the metadata for this dataset.
					%if can_edit:
						You may be able to <a href="${h.url_for( controller='dataset', action='edit', dataset_id=dataset_id )}" target="galaxy_main">set it manually or retry auto-detection</a>.
					%endif
				</div>
			%endif
			
			<pre class="section_title">Informations:</pre>
			
			<div class="job_info" style="margin: 0px">
				<table class="tooldata">

					<tbody>
						<tr><td class="left">Creation time:</td><td>${data.create_time.isoformat(' ')}</td></tr>
						<tr class="blank_line"><td colspan=2></td></tr>
						
						<tr><td class="left">File size:</td><td>${data.get_size(nice_size=True)}</td></tr>
						<tr><td class="left">File format:</td><td>${data.ext} (${data.get_mime()})</td></tr>
						%if trans.user_is_admin() or trans.app.config.expose_dataset_path:
							<tr><td class="left">Full Path:</td><td>${data.get_file_name()}</td></tr>
						%endif
						<tr class="blank_line"><td colspan=2></td></tr>
						
						## Display specific metadata
						<% all_metadata = data.get_metadata() %>

						<tr><td class="left">Number of lines:</td><td>${all_metadata.get('data_lines')}</td></tr>
						%if all_metadata.get('sequences') != None:
							<tr><td class="left">Number of sequences:</td><td>${all_metadata.get('sequences')}</td></tr>
						%endif
						
						## Display info
						%if data.display_info():
							<tr class="blank_line"><td colspan=2></td></tr>
							<tr><td class="left">Additional data:</td><td>${data.display_info()}</td></tr>
						%endif
					</tbody>
				</table>

			</div>
			
			## Display a peek of the dataset
			%if data.peek != "no peek":
				<pre class="section_title">Peek:</pre>
				<pre id="peek${data.id}" class="peek">${_(h.to_unicode(data.display_peek()))}</pre>
			%endif
			
			## Display inheritance chain
			%if inherit_chain_list[data.id]:
				
				<% 
					heritage = []
					
					for dep in reversed(inherit_chain_list[data.id]):
						if dep[1] == "(Data Library)":
							heritage.append("Data library")
						else:
							heritage.append("History - " + dep[1] + " (" + dep[0].name + ")")
				
					heritage.append("Current Dataset (" + data.name + ")")
				%>
				
				<pre class="section_title">Inheritance Chain:</pre>
				
				<div class="job_info" style="margin: 0px">
					<% counter = 0 %>
					<table class="legacy_table">
						%for member in heritage:
							<tr>
								${ indent_element( text= member, depth= counter )}
							</tr>
							<% counter = counter +1 %>
						%endfor
					</table>
				</div>
			%endif
			
		## Unknown state
		%else:
			<div>${_('Error: unknown dataset state "%s".') % data_state}</div>
		%endif
		   
		## Recurse for child datasets
		%if len( data.children ) > 0:
			## FIXME: This should not be in the template, there should be a 'visible_children' method on dataset.
			<%
			children = []
			for child in data.children:
				if child.visible:
					children.append( child )
			%>
			%if len( children ) > 0:
				<div>
					There are ${len( children )} secondary datasets.
					%for idx, child in enumerate(children):
						${render_dataset( child, idx + 1 )}
					%endfor
				</div>
			%endif
		%endif

		<div style="clear: both;"></div>
	</div>
</div>

</%def>
