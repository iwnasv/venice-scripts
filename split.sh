#!/bin/bash
# USAGE: cd to /importers and run split.sh

LOGFILE=/tmp/dspace-batch-split.log
BATCHSIZE=500
POOL="../pool"

while getopts "s:" opt
do
  case $opt in
    s)
      if [[ $OPTARG -gt 0 ]]; then
        BATCHSIZE=$OPTARG
      fi
      ;;
    *)
      echo "Usage: split.sh [-s batchsize]"
      exit 1
      #TODO: -p for pool path
      ;;
  esac
done

log () {
  if [[ -f $LOGFILE ]]; then
    if [[ -w $LOGFILE ]]; then
      echo "$1" >> $LOGFILE
    else
      echo "can't write to log file!"
    fi
  else
    printf "%s\n" "$1" > $LOGFILE || echo "can't create log file!"
  fi
}

onfail () {
  if [[ $? -ne 0 ]]; then
    echo "[$(date '+%x %X')] FAILED: refer to $LOGFILE."
    log "$1"
    exit 1
  fi
}

validate () {
    if [[ $(count-items.py "$1") -ne 0 ]]
  then
    return 1
  else
    echo test # this works for the if statement used later, it's fine. just 0 exit code doesn't do it.
  fi
}

dircount=0
batchcount=0

if [[ ! -w . ]]; then
  echo "Error: split.sh is run in a directory it doesn't have write permission in."
  echo "Please type a user to sudo -u as (or su if that fails) and resume operation."
  echo "examples: dspace, root (CTRL+C kills me)"
  read NEWSER #new user. haha.
  if [[ $(id -u $NEWSER) -eq 0 ]]; then # handle root login elegantly, and ensure new user is real before login attempts
    sudo -i || su
  elif [[ $(id -u $NEWSER) -gt 0 ]]; then
    sudo -i -u $NEWSER || su $NEWSER
  else
    echo "$NEWSER is not a real user, there's only so much I can do... exiting :("
    exit 1
  fi
fi

for dir in *; do
  if [[ -d "$dir" && $(validate "$dir") ]]; then
    if [[ $dircount -eq 0 ]]; then
      ((batchcount++))
      mvto="$POOL/$(date '+%F')-$batchcount"
      mkdir $mvto
      log "Batch $batchcount starting at $dir is in $mvto"
    fi
    cp -r $dir $mvto
    onfail "FATAL: couldn't move $pwd/$dir to $mvto. Ensure this is a dspace importers directory and you've got the right permissions. Exiting with error code 1. $(date '+%x %X')."
    log "    $dir"
    ((dircount++))
    if [[ $dircount -eq $BATCHSIZE ]]; then
      log "$mvto: $BATCHSIZE entries end at $dir"
      log "--"
      dircount=0
    fi
  fi
done

for file in *; do
  if [[ -f $file ]]; then
    log "Leftover file: ${file}. Please confirm (${pwd}/${file})"
  fi
done

log ""
log "A total of $batchcount batch import directories were made in $(pwd)"
exit 0
