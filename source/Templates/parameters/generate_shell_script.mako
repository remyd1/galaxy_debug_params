<%
        from os import getenv
        from galaxy import config
        from galaxy import model

        #~ from sqlalchemy.orm.collections import InstrumentedList

        import re


        # Initializations
        Bash_lines = list()
        Tool_counter = 0
        Unknown_counter = 0
        Clean_history_name = history.get_display_name().replace(' ', '_')
        #transform each path config val in bash variable for the script
        conf = config.Configuration()

        dataset_pattern = re.compile('.+\.dat')

        wdir = app.config.get('job_working_directory', conf.job_working_directory)
        fpath = app.config.get('file_path', conf.file_path)
        libdir = app.config.get('library_import_dir', conf.library_import_dir)
        tdatapath = app.config.get('tool_data_path', conf.tool_data_path)
        clfilespath= app.config.get('cluster_files_directory', conf.cluster_files_directory)
        ftpdir = app.config.get('ftp_upload_dir', conf.ftp_upload_dir)
        tpath = app.config.get('tool_path', conf.tool_path)

        paths = {'JOB_WORKING_DIR': wdir, \
                'FILE_PATH': fpath, \
                'LIB_IMPORT_DIR': libdir,\
                'TOOL_DATA_PATH': tdatapath,\
                'CL_FILES_DIR': clfilespath,\
                'FTP_DIR': ftpdir,\
                'TOOL_PATH': tpath }
        # Shebang and directory creation
        try:
                shell = getenv('SHELL')
        except:
                shell = "/bin/bash"
        Bash_lines.append('#!' + shell + "\n")
        Bash_lines.append('mkdir ' + Clean_history_name)
        Bash_lines.append('cd ' + Clean_history_name + "\n")


        for k, val in paths.iteritems():
                if val:
                        Bash_lines.append(k+'=' + "'" + str(val) + "'")
        Bash_lines.append('\n')

        # Tool command lines
        for jobs_ID, First_dataset_identifier in First_dataset_by_job.items():

                Interpreter = ""

                #~ Bash_lines.append(type(job_list[First_dataset_identifier]))
                job_properties = { \
                'params': job_list[First_dataset_identifier].get_params(),\
                'param_file': job_list[First_dataset_identifier].get_param_filename(),\
                #~ 'parameters': job_list[First_dataset_identifier].get_parameters(),\
                'param_values': job_list[First_dataset_identifier].get_param_values(trans.app),\
                'post_job_actions': job_list[First_dataset_identifier].get_post_job_actions(),\
                'command_line': job_list[First_dataset_identifier].get_command_line(),\
                'input_lib_dataset': job_list[First_dataset_identifier].get_input_library_datasets(),\
                'output_lib_dataset': job_list[First_dataset_identifier].get_output_library_datasets(),\
                'input_datasets': job_list[First_dataset_identifier].get_input_datasets(),\
                'output_datasets': job_list[First_dataset_identifier].get_output_datasets(),\
                #~ 'pifc': job_list[First_dataset_identifier].get_prepare_input_files_cmd(),\
                'info': job_list[First_dataset_identifier].get_info(),\
                'output_metas': job_list[First_dataset_identifier].get_external_output_metadata(),\
                'job': job_list[First_dataset_identifier].get_job(),\
                'id': job_list[First_dataset_identifier].get_id(),\
                'id_tag': job_list[First_dataset_identifier].get_id_tag(),\
                'tasks': job_list[First_dataset_identifier].get_tasks(),\
                'tool_id': job_list[First_dataset_identifier].get_tool_id(),\
                'tool_version': job_list[First_dataset_identifier].get_tool_version(),\
                'user': job_list[First_dataset_identifier].get_user().email,\
                }

                Bash_lines.append("\n")
                Bash_lines.append("# Properties of job")
                for k, prop in job_properties.iteritems():
                        if prop:
                                if hasattr(prop, '__instrumentation__'):
                                        # use enumerate because it is not a standard list (sqlachemy)
                                        for i in enumerate(prop):
                                                my_galaxy_obj = i[1]
                                                try:
                                                        if isinstance(my_galaxy_obj, model.JobExternalOutputMetadata):
                                                                Bash_lines.append("#" + k +"("+str(i[0])+"): " + str(my_galaxy_obj.dataset.name))
                                                        elif isinstance(my_galaxy_obj, model.JobToOutputDatasetAssociation):
                                                                Bash_lines.append("#" + k + "("+str(i[0])+") name: " + my_galaxy_obj.name + " , dataset: " + str(my_galaxy_obj.dataset.name))
                                                        elif isinstance(my_galaxy_obj, model.JobToInputDatasetAssociation):
                                                                Bash_lines.append("#" + k + "("+str(i[0])+") name: " + my_galaxy_obj.name + " , dataset: " + str(my_galaxy_obj.dataset.name))
                                                        #~ elif isinstance(my_galaxy_obj, model.JobParameter):
                                                                #~ Bash_lines.append("#" + k + "("+str(i[0])+") name: " + my_galaxy_obj.name + " , value: " + my_galaxy_obj.value)
                                                except AttributeError:
                                                        Bash_lines.append("#" + k + ": is not a model item ("+str(prop)+")"+ str(type(prop)))
                                else:
                                        Bash_lines.append("#" + k + ": " + str(prop))
                Bash_lines.append("# End of properties")

                if tool_list[First_dataset_identifier]:
                        #~ Bash_lines.append(type(tool_list[First_dataset_identifier]))
                        Raw_tool_name = tool_list[First_dataset_identifier].name
                        Interpreter = tool_list[First_dataset_identifier].interpreter
                        Interpreter = Interpreter + " "
                        inputs = tool_list[First_dataset_identifier].inputs
                        #~ Bash_lines.append(inputs)
                        #~ Bash_lines.append(Interpreter)
                else:
                        Unknown_counter = Unknown_counter + 1
                        Raw_tool_name = "Unknown_Tool_" + str(Unknown_counter)
                # Edit command line
                Clean_tool_name = Raw_tool_name.replace(' ', '_')
                Redirection = ' 1> ' + Clean_tool_name + '.stdout' + ' 2> ' + Clean_tool_name + '.stderr'
                Raw_command = job_list[First_dataset_identifier].command_line

                if Raw_command is not None:
                        if "1>" in Raw_command:
                                Command_no_redir = Raw_command.partition('1>')[0]
                        else:
                                Command_no_redir = Raw_command.partition('>')[0]

                        # custom edition for PopPhyl tools
                        if "exec_mode=galaxy" in Command_no_redir:
                                Command_exec_mode = Command_no_redir.replace("exec_mode=galaxy", "exec_mode=local")
                        elif "exec galaxy" in Command_no_redir:
                                Command_exec_mode = Command_no_redir.replace("exec galaxy", "exec local")
                        else:
                                Command_exec_mode = Command_no_redir

                        Final_command_line = " ".join(Command_exec_mode.replace("\t",'').split())

                        dataset_path = ""
                        Tool_counter = Tool_counter + 1
                        if Raw_tool_name != "Upload File":
                                Workdir = str(Tool_counter) + '_' + Clean_tool_name

                                Bash_lines.append("# Tool name: " + Raw_tool_name)
                                all_params = re.split(" ",Final_command_line)
                                j = 0
                                if len(Associated_datasets_by_job[jobs_ID]) > 0:
                                        for dataset in Associated_datasets_by_job[jobs_ID]:
                                                j = j+1
                                                Bash_lines.append("DATASET_NAME_"+str(j)+"='"+dataset[1].replace("'","\\'")+"'")
                                                dataset_path="DATASET_RESULT_PATH_"+str(j)+"=\""+dataset[2]+"\""
                                                #~ Final_command_line = Final_command_line.replace(dataset[2],"$DATASET_RESULT_PATH")
                                                Final_command_line = Final_command_line.replace(dataset[2],"$DATASET_RESULT_PATH_"+str(j))
                                for k, val in paths.iteritems():
                                        Final_command_line = Final_command_line.replace(str(val),"$"+k)
                                        if dataset_path != "":
                                                dataset_path = dataset_path.replace(str(val),"$"+k)
                                Bash_lines.append("JOB_ID='"+str(jobs_ID)+"'")
                                if dataset_path != "":
                                        dataset_path = dataset_path.replace("/"+str(jobs_ID)+"/","/$JOB_ID/")
                                        Bash_lines.append(dataset_path)
                                Bash_lines.append('mkdir ' + Workdir)
                                Bash_lines.append('cd ' + Workdir)
                                i = 0
                                Final_command_line = Final_command_line.replace("'","\\'")
                                #~ Final_command_line = Final_command_line.replace('"','\\"')
                                Final_command_line = Final_command_line.replace("/"+str(jobs_ID)+"/","/$JOB_ID/")
                                for k,string in enumerate(all_params):
                                        sub_string = string.split("=")
                                        for sub_str in sub_string:
                                                if re.match(dataset_pattern, sub_str):
                                                        i = i+1
                                                        sub_str = sub_str.replace("'","\\'")
                                                        sub_str = sub_str.replace('"',"")
                                                        sub_str = sub_str.replace("/"+str(jobs_ID)+"/","/$JOB_ID/")
                                                        for k, val in paths.iteritems():
                                                                sub_str = sub_str.replace(str(val),"$"+k)
                                                        Bash_lines.append("DAT_PATH_"+str(i)+"=\""+sub_str+"\"")
                                                        Final_command_line = Final_command_line.replace(sub_str,"$DAT_PATH_"+str(i))
                                        if k == 0:
                                                string = string+" "
                                                Interpreter = string
                                        if k == 1:
                                                string = string+" "
                                                Final_command_line = Final_command_line.replace(string,"")
                                                File2execute = string

                                if Interpreter:
                                        Final_command_line = Final_command_line.replace(Interpreter,"")

                                Bash_lines.append(Interpreter + File2execute + Final_command_line + Redirection)
                                Bash_lines.append('cd ..' + "\n")

        Bash_lines.append('cd ..' + "\n")


%>\
\
%if not trans.user_is_admin():
Access denied for non-administrator users !
%else:
 %for lines in Bash_lines:
${lines}
 %endfor
%endif
