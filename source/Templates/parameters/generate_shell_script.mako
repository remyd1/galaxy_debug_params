<%
        from os import getenv
        from galaxy import config
        #import galaxy.model.mapping
        import re

        # Initializations
        Bash_lines = list()
        Tool_counter = 0
        Unknown_counter = 0
        Clean_history_name = history.get_display_name().replace(' ', '_')
        #transform each path config val in bash variable for the script
        conf = config.Configuration()

        dataset_pattern = re.compile('.+\.dat')

        wdir = app.config.get('job_working_directory', \
        conf.job_working_directory)
        fpath = app.config.get('file_path', conf.file_path)
        libdir = app.config.get('library_import_dir', \
        conf.library_import_dir)
        tdatapath = app.config.get('tool_data_path', conf.tool_data_path)
        clfilespath= app.config.get('cluster_files_directory', \
        conf.cluster_files_directory)
        ftpdir = app.config.get('ftp_upload_dir', conf.ftp_upload_dir)
        tpath = app.config.get('tool_path', conf.tool_path)

        paths = {'JOB_WORKING_DIR': str(wdir), \
                'FILE_PATH': str(fpath), \
                'LIB_IMPORT_DIR': str(libdir),\
                'TOOL_DATA_PATH': str(tdatapath),\
                'CL_FILES_DIR': str(clfilespath),\
                'FTP_DIR': str(ftpdir),\
                'TOOL_PATH': str(tpath) }
        # Shebang and directory creation
        try:
                shell = getenv('SHELL')
        except:
                shell = "/bin/bash"
        Bash_lines.append('#!' + shell + "\n")
        Bash_lines.append('mkdir ' + Clean_history_name)
        Bash_lines.append('cd ' + Clean_history_name + "\n")


        for k, val in paths.iteritems():
                Bash_lines.append(k+'=' + "'" + val + "'")
        Bash_lines.append('\n')

        # Tool command lines
        for jobs_ID, First_dataset_identifier in First_dataset_by_job.\
        items():


                if tool_list[First_dataset_identifier]:
                        Raw_tool_name = tool_list[\
                        First_dataset_identifier].name
                else:
                        Unknown_counter = Unknown_counter + 1
                        Raw_tool_name = "Unknown_Tool_" + \
                        str(Unknown_counter)
                # Edit command line
                Clean_tool_name = Raw_tool_name.replace(' ', '_')
                Redirection = ' 1> ' + Clean_tool_name + \
                '.stdout' + ' 2> ' + Clean_tool_name + '.stderr'
                Raw_command = job_list[First_dataset_identifier].\
                command_line

                if Raw_command is not None:
                        if "1>" in Raw_command:
                                Command_no_redir = Raw_command.\
                                partition('1>')[0]
                        else:
                                Command_no_redir = Raw_command.\
                                partition('>')[0]

                        # custom edition for PopPhyl tools
                        if "exec_mode=galaxy" in Command_no_redir:
                                Command_exec_mode = Command_no_redir.\
                                replace("exec_mode=galaxy", \
                                "exec_mode=local")
                        elif "exec galaxy" in Command_no_redir:
                                Command_exec_mode = Command_no_redir.\
                                replace("exec galaxy", "exec local")
                        else:
                                Command_exec_mode = Command_no_redir

                        Final_command_line = " ".join(Command_exec_mode.\
                        replace("\t", '').split()) + Redirection

                        dataset_path = ""
                        if Raw_tool_name != "Upload File":
                                Tool_counter = Tool_counter + 1
                                Workdir = str(Tool_counter) + '_' + \
                                Clean_tool_name

                                Bash_lines.append("# Tool name: " + \
                                Raw_tool_name)
                                all_params = re.split(" ",Final_command_line)
                                j = 0
                                if len(Associated_datasets_by_job[jobs_ID]) > 0:
                                        for dataset in \
                                        Associated_datasets_by_job[jobs_ID]:
                                                j = j+1
                                                Bash_lines.append(\
                                                "DATASET_NAME_"+str(j)+"='"+\
                                                dataset[1].replace("'","\\'")+\
                                                "'")
                                                dataset_path="DATASET_"+\
                                                "RESULT_PATH_"+str(j)+"=\""+\
                                                dataset[2]+"\""
                                                Final_command_line = \
                                                Final_command_line.replace(\
                                                dataset[2],"$DATASET_RESULT_PATH")
                                for k, val in paths.iteritems():
                                        Final_command_line = Final_command_line.\
                                        replace(val,"$"+k)
                                        if dataset_path != "":
                                                dataset_path = dataset_path.\
                                                replace(val,"$"+k)
                                Bash_lines.append("JOB_ID='"+str(jobs_ID)+"'")
                                if dataset_path != "":
                                        dataset_path = dataset_path.replace(\
                                        "/"+str(jobs_ID)+"/","/$JOB_ID/")
                                        Bash_lines.append(dataset_path)
                                Bash_lines.append('mkdir ' + Workdir)
                                Bash_lines.append('cd ' + Workdir)
                                i = 0
                                Final_command_line = Final_command_line.replace(\
                                "'","\\'")
                                Final_command_line = Final_command_line.replace(\
                                "/"+str(jobs_ID)+"/","/$JOB_ID/")
                                for string in all_params:
                                        sub_string = string.split("=")
                                        for sub_str in sub_string:
                                                if re.match(dataset_pattern,\
                                                sub_str):
                                                        i = i+1
                                                        sub_str = sub_str.\
                                                        replace("'","\\'")
                                                        sub_str = sub_str.\
                                                        replace('"',"")
                                                        sub_str = sub_str.\
                                                        replace("/"+str(jobs_ID\
                                                        )+"/","/$JOB_ID/")
                                                        for k, val in paths.\
                                                        iteritems():
                                                                sub_str = sub_str.\
                                                                replace(val,"$"+k)
                                                        Bash_lines.append(\
                                                        "DAT_PATH_"+str(i)+"=\""+\
                                                        sub_str+"\"")
                                                        Final_command_line = \
                                                        Final_command_line.\
                                                        replace(sub_str,\
                                                        "$DAT_PATH_"+str(i))
                                Bash_lines.append(Final_command_line)
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
