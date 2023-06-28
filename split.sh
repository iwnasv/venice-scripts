#!/bin/bash
# USAGE: cd to /importers and ./split.sh

LOGFILE=/var/log/dspace-import-batch-split.log
BATCHSIZE=500 # to do: argument
log () {
  if [[ -f $LOGFILE ]]
  then
    echo $1 >> $LOGFILE
  else
    echo $1 > $LOGFILE
  fi
}

onfail () {
  if [[ $? -ne 0 ]]
  then
    echo "[$(date '+%x %X')] FAILED: refer to $LOGFILE."
    log "$1"
    exit 1
  fi
}

let 'dircount = 0, batchcount = 0'

if [[ $(basename $(pwd)) != "importers" ]]
then
  echo "Warning: split.sh is run in a directory not named 'importers'"
  echo "Press enter if you're sure this directory contains dspace importers"
  echo "Changes WILL be written on disk if you do so! CTRL+C kills me"
  echo "(you probably want to cd ~dspace/importers)"
  read
fi
if [[ ! -w . ]]
then
  echo "Error: split.sh is run in a directory it doesn't have write permission in."
  echo "Please type a user to sudo -u as (or su if that fails) and resume operation."
  echo "examples: dspace, root (CTRL+C kills me)"
  read NEWSER #new user. haha.
  if [[ $(id -u $NEWSER) -eq 0 ]]
  then
    sudo -i || su
  elif [[ $(id -u $NEWSER) -gt 0 ]]
  then
    sudo -i -u $NEWSER || su $NEWSER
  else
    echo "$NEWSER is not a real user, there's only so much I can do... exiting :("
    exit 1
  fi
fi

for dir in *
do
  if [[ -d $dir ]]
  then
    if [[ $dircount -eq 0 ]]
    then
      let 'batchcount++'
      mvto="$(date '+%F')-$batchcount"
      mkdir $mvto
      log "Batch $batchcount starting at $dir is in $mvto"
    fi
    mv $dir $mvto
    onfail "FATAL: couldn't move $pwd/$dir to $pwd/$mvto. Ensure this is a dspace importers directory and you've got the right permissions. Exiting with error code 1. $(date '+%x %X')."
    log "$dir"
    let 'dircount++'
    if [[ $dircount -eq $BATCHSIZE ]]
    then
      log "$mvto: $BATCHSIZE entries end at $dir"
      let 'dircount = 0'
    fi
  fi
done
for file in *
do
  if [[ -f $file ]]
  then
    log "Leftover file: ${file}. Please confirm (${pwd}/${file})"
  fi
log "A total of $batchcount batch import directories where made in $(pwd)"
