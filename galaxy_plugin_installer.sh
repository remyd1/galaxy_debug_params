#!/bin/bash

# Parameters initializations
galaxy_dist=''

# Functions
function help
{
	echo -e "################################################################"
	echo -e "#     Galaxy Plugin Installer (Version 1.5) - HELP section     #"
	echo -e "################################################################\n"
	
	echo -e "Usage example: galaxy_plugin_installer.sh -d $HOME/galaxy-dist\n"
	
	echo -e "Here is the list of authorized parameters :\n";
	
	echo -e " -h => Display this help message.\n";
	
	echo -e " -d directory => Absolute path to the galaxy-dist directory containing your galaxy instance (mandatory).\n";
    
    echo -e "\n\n /!\ Use this installer only after you installed galaxy, not after an upgrade. If you upgrade galaxy, consider to re-apply this script or copy the files needed."

	exit 0
}

function check
{
	if [[ ! -e $1 ]]; then
		echo -e "Error: file/directory $1 does not exists ! Installation aborted...\n"
		exit
	fi
	
}

# Get options from the command line
while getopts d:h opt;
	do case $opt in
		d) galaxy_dist=$OPTARG;;
		h) help;;
	esac
done

# Check entered directory path
if [[ $galaxy_dist == "" ]]; then
	echo -e "Error: Mandatory -d parameter is missing !\n"
	help
fi

if [[ ! -d $galaxy_dist ]]; then
	echo -e "Error: directory $galaxy_dist does not exists ! Please try again !\n"
fi

galaxy_dist=${galaxy_dist%/}

# Initializations
static_dir=${galaxy_dist}/static
blue_theme_dir=${static_dir}/june_2007_style/blue
js_dir=${static_dir}/scripts

templates_dir=${galaxy_dist}/templates
base_panel_dir=${templates_dir}/webapps/galaxy

controller_dir=${galaxy_dist}/lib/galaxy/webapps/galaxy/controllers

plugin_name="parameters"

timestamp=`date +"%m-%d-%Y_%Hh%M"`
mako_backup_name="base_panels.mako.backup_"${timestamp}
js_menu_backup="galaxy.menu.js.backup_"${timestamp}


echo -e "#################################################################"
echo -e "#             Galaxy plugin installer (Version 1.5)             #"
echo -e "#################################################################\n"

if [[ ! -d $galaxy_dist ]]; then
	echo -e "Error: directory $galaxy_dist does not exists ! Please login with the correct username !\n"
else
	echo -e "All needed files will now be copied in the appropriate directories !\n"

	if [[ -d "source" ]]; then
		cd source
		
		echo -e " -> Copy of CSS stylesheet in directory ${blue_theme_dir}"
		cp CSS/${plugin_name}.css ${blue_theme_dir}/
		check ${blue_theme_dir}/${plugin_name}.css
		
		echo -e " -> Copy of Mako templates in directory ${templates_dir}/${plugin_name}/"
		cp -R Templates/${plugin_name} ${templates_dir}/
		check ${templates_dir}/${plugin_name}
		
		echo -e " -> Copy of the custom controller in directory ${controller_dir}/"
		cp Controller/${plugin_name}.py ${controller_dir}/
		check ${controller_dir}/${plugin_name}.py
		
		#echo -e "\n -> Creation of a backup of the original base_panels.mako file (Backup name: $mako_backup_name)"
		#cp ${base_panel_dir}/base_panels.mako ${base_panel_dir}/${mako_backup_name}
		
		#echo -e " -> Copy of the custom base_panels.mako in directory ${base_panel_dir}/"
		#cp Menu/custom_base_panels.mako ${base_panel_dir}/base_panels.mako
		#check ${base_panel_dir}/base_panels.mako
		
		echo -e "\n -> Creation of a backup of the original galaxy.menu.js file (Backup name: $js_menu_backup)"
		cp ${js_dir}/galaxy.menu.js ${js_dir}/${js_menu_backup}
		
		echo -e " -> Copy of the custom galaxy.menu.js in directory ${js_dir}/"
		cp Menu/static/scripts/galaxy.menu.js ${js_dir}/galaxy.menu.js
		check ${js_dir}/galaxy.menu.js
		
		echo -e "\n  --> Installation complete !\n"
		
		cd ..
	else
		echo -e "Error: mandatory directory <source> does not exists !\n"
	fi
fi

echo -e "#################################################################"
echo -e "#                        End of execution                       #"
echo -e "#################################################################"
