IP=162.38.181.220

# utile pour eviter la saisie invisible si on fait ctrl-c pendant la saisie de mdp
trap ctrl_c INT
function ctrl_c() {
    stty echo
    exit
}

function printUsage(){
echo "usage :
$0 [-u USER] [-n] [files]

[-u | --user USER] : user on distant machine
[-n] if you can connect by ssh on distant machine without password
[files] if you want to also update specific files

This scripts deploys a working copy of web repository to mbb-bis.

All new (added by 'git add FILE') and modified (tracked by the repository) 
files since last commit and specific file passed as arguments are copied.
"
}

ARGS=$(getopt -o u:n -l "user:" -n "$0" -- "$@");

#Bad arguments
if [ $? -ne 0 ] || [ $# -eq 0 ];
then
    printUsage
    exit
fi
USERFLAG=0
NOSSHPASSFLAG=0
eval set -- "$ARGS";

while true; do
    case "$1" in
        -n)
            NOSSHPASSFLAG=1
            shift;
            ;;
        -u|--user)
            shift;
            if [ -n "$1" ]; then
                USERFLAG=1
                UNIXUSER=$1
            else
                echo "You have to set a username"
                printUsage
                exit
            fi
            shift;
            ;;
        --)
            break;
            ;;
    esac
done

FILELIST=()
# recupération des fichiers additionnels à deploy (les non-option arguments)
shift;
while [ -n "$1" ]; do
    FILELIST+=($1)
    if ! [ -f $1 ]; then
        echo "File $1 does not exist"
        exit
    fi
    shift
done

# si on doit se connecter en SSH avec mot de passe, il faut sshpass
if [[ $NOSSHPASSFLAG == 0 ]]; then
    test -f /usr/bin/sshpass || { echo 'Vous devez installer sshpass' ; exit; }
fi

if [ $USERFLAG == 0 ]; then
    echo "You didn't set a username, so $USER will be used"
    UNIXUSER=$USER
fi

# on récupère la liste de fichiers modifiés ou nouveaux
NEW=`git diff --cached --name-only --diff-filter=A | grep -v deploy`
MODIFIED=`git ls-files -m | grep -v deploy`
if [ -n "$NEW" ];then
    FILELIST+=($NEW)
fi
if [ -n "$MODIFIED" ];then
    FILELIST+=($MODIFIED)
fi

if [ ${#FILELIST[*]} == 0 ]; then
    echo "There is no file to deploy"
    exit
fi


# Creation de l'archive des fichiers modifiés et nouveaux
rm -rf MBB
mkdir MBB
for file in ${FILELIST[*]}; do
    dir=`dirname $file`
    mkdir -p MBB/$dir
    cp $file MBB/$dir
done
tar czvf MBB.tar.gz MBB
rm -rf MBB

# demande du mot de passe pour la connexion ssh et pour le sudo sur la machine distante
stty -echo
echo -n "Please enter your passwd: "
read REMOTESUDOPASSWD
echo
stty echo

# si on a pas de clé ssh sans mot de passe
if [ $NOSSHPASSFLAG == 0 ]; then
    sshpass -p $REMOTESUDOPASSWD scp MBB.tar.gz $UNIXUSER@$IP:
    TRANSFERSUCCESS=$?
    if [[ $TRANSFERSUCCESS -ne 0 ]]; then
        echo "!!! Mauvais mot de passe ou problème de connexion ($TRANSFERSUCCESS)"
        exit                                                     
    fi          
    sshpass -p $REMOTESUDOPASSWD ssh -t -t -t $UNIXUSER@$IP "tar xzvf MBB.tar.gz"
    sshpass -p $REMOTESUDOPASSWD ssh -t -t -t $UNIXUSER@$IP "sudo -S cp -r MBB /var/www/ <<EOF
$REMOTESUDOPASSWD
EOF
"
    COPYSUCCESS=$?
    sshpass -p $REMOTESUDOPASSWD ssh -t -t -t $UNIXUSER@$IP "rm -rf MBB MBB.tar.gz"
    if [[ $TRANSFERSUCCESS == 0 ]] && [[ $COPYSUCCESS == 0 ]]; then
        echo
        echo "!!!! Le déploiement s'est bien passé, les fichiers suivant ont été copiés :"
        echo
        for i in ${FILELIST[*]}; do echo $i; done
    else
        echo "!!!! Un problème est survenu : transfer : $TRANSFERSUCCESS, copy : $COPYSUCCESS"
    fi
# si on se logue sans mot de passe
else 
    scp MBB.tar.gz $UNIXUSER@$IP:
    TRANSFERSUCCESS=$?
    ssh -t -t -t $UNIXUSER@$IP "tar xzvf MBB.tar.gz"
    ssh -t -t -t $UNIXUSER@$IP "sudo -S cp -r MBB /var/www/ <<EOF
$REMOTESUDOPASSWD
EOF
"
    COPYSUCCESS=$?
    ssh -t -t -t $UNIXUSER@$IP "rm -rf MBB MBB.tar.gz"
    if [[ $TRANSFERSUCCESS == 0 ]] && [[ $COPYSUCCESS == 0 ]]; then
        echo
        echo "!!!! Le déploiement sur MBB s'est bien passé, les fichiers suivant ont été copiés :"
        echo
        for i in ${FILELIST[*]}; do echo $i; done
    else
        echo "!!!! Un problème est survenu : transfer : $TRANSFERSUCCESS, copy : $COPYSUCCESS"
    fi
fi

