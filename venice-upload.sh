#!/bin/bash

#venice defaults
SENDER="dspace-uploader"
LOGFILE="/var/log/rsync.log"
SERVER="ie-vm1.theo.auth.gr"
SOURCE="/mnt/g/Process/web/"
DEST="/mnt/data/web"
SSHUSER="administrator" # for post-upload ssh
IMPORT_SCRIPT="https://github.com/iwnasv/venice-scripts/raw/main/venice-import.sh" # Called at the script's end if the user wants it to

function ex () { # explode
  echo "[ERROR]: $1"
  exit 1
}

while getopts "hu:l:s:S:D:v:p:" opt
do
  case $opt in
    h)
      echo "$(basename $0): Project data sync"
      echo "Safely send dspace-related data to remote servers over SSH with rsync"
      echo "Usage: $0 [-u sender-username] [-l logfile] [-s server-address OR -v vm-number(1-3)] [-S sync-source-root] [-D dest-source-root] [-p subdirectory]"
      echo "For VM #2, source & dest are set; save bandwidth and time by using -s to as low a level as you can"
      echo "No trailing slashes, ever!"
      exit 0
      ;;
    u)
      SENDER="$OPTARG" ;;
    l)
      LOGFILE="$OPTARG" ;;
    s)
      SERVER="$OPTARG" ;;
    S)
      if [[ ! -d "$OPTARG" ]]
      then
        ex "Source directory not found"
      fi
      SOURCE="$OPTARG" ;;
    D)
      DEST="$OPTARG" ;;
    v)
      if [[ $OPTARG -ge 1 && $OPTARG -le 3 ]]
      then
        SERVER="ie-vm${OPTARG}.theo.auth.gr" # to do: sed?
      else
        ex "Venice VMs range is 1-3"
      fi
      ;;
    p)
      SUBDIR="$OPTARG" ;;
  esac
done

if ! sudo -v >/dev/null &2>1
then
  echo "For best experience, sudoer power is recommended."
fi
rsync -e "sudo -u $SENDER ssh -i ~${SENDER}/.ssh/id_rsa" -zh --info=name,progress2 --ignore-existing --log-file="$LOGFILE" -r "$SOURCE/$SUBDIR" "dspace@${SERVER}:$DEST/$SUBDIR"
if [[ $? -eq 0 ]]
then
  echo "Done; would you like to import the data to dspace?"
  echo "Reminder that you copied data to $DEST on $SERVER."
  echo "This next step is only relevant for importers, not media data."
  echo "Type 'n' to quit now, otherwise write the arguments you want to pass to the import script."
  read answer # $answer is either n (quit) or arguments
  if [[ $answer != "n" ]]
  then
    echo "Input SSH server, or press enter to use $SERVER"
    read SSHSERVER
    if [[ -z $SSHSERVER ]]
    then
      SSHSERVER="$SERVER"
    fi
    if [[ ${IMPORT_SCRIPT:0:5} == "https" ]]
    then
      # if it's a url, curl it, otherwise just execute it
      curl -s "$IMPORT_SCRIPT" | ssh $SSHUSER@$SSHSERVER -i ~/.ssh/id_rsa "bash -s -- $answer" | tee ${LOGFILE:0:-4}-ssh.log
    else
      ssh $SSHUSER@$SSHSERVER -i ~/.ssh/id_rsa "bash -s -- $answer" < $IMPORT_SCRIPT | tee ${LOGFILE:0:-4}-ssh.log
    fi
  else
    exit 0
  fi
else
  echo "rsync failed! refer to $LOGFILE"
  exit 1
fi
