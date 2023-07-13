#!/bin/bash
# USAGE: Not much to do, you just call the script this time
# It expects ~dspace to have the importers and mapfiles directories

# Rizar defaults
COLLECTION=b8592740-5693-4c94-832e-b147564c1127
EPERSON="info@res.gr"
IMPORTERSDIR=/opt/data/importers
ZIP=/home/dspace/importers/archive.zip
DSPACE_IMPORT_LOG="/home/dspace/import-logs/0.log"
DSPACE_IMPORT_LOG_FAIL="/home/dspace/import-logs/fail.log"
SUCCESSFUL=/tmp/successful-ids

askme () {
    if [[ -n $ASKME ]]
    then
      echo "$1"
      echo "Press enter to continue or ctrl+c to quit"
    fi
    read
}

while getopts "c:e:p:C" opt
do
  case $opt in
    c)
      COLLECTION="$OPTARG" ;;
    e)
      EPERSON="$OPTARG" ;;
    p)
      PASSWORD="$OPTARG" ;; # echo $PASSWORD | sudo -u dspace -S
    C)
      ASKME="TRUE" ;; # ask me before doing anything; for tests and scripting
      # note: TRUE is a string, not a boolean.
    h)
      echo "$(basename $0): Project data dspace import"
      echo "Usage: $(basename $0) [-c COLLECTION] [-e E-PERSON] [-p DSPACE_UNIX_USER_PASSWORD] [-C]"
      echo "-C asks for confirmation each time before doing anything important, -p is there for testing and possible future automations"
      ;;
  esac
done

if [[ ! -d $IMPORTERSDIR || ! -d ~dspace/mapfiles || ! -w $IMPORTERSDIR || ! -w ~dspace/mapfiles ]] # both directories present and writable
# using -d as well to ensure it's a directory and not a regular file
then
  echo "This script expects the importers and mapfiles directories present under ~dspace and writable by the dspace user."
  exit 1
fi

if [[ -f $SUCCESSFUL ]]
then
  rm $SUCCESSFUL
fi

if [[ -f  $ZIP ]]
then
  cp $ZIP ${ZIP}.old
  echo OLD: $(sha256sum -z "$ZIP") > ~dspace/importers-backup-integrity.txt
  date "+%x %X" >> ~dspace/importers-backup-integrity.txt
fi

if [[ -f $DSPACE_IMPORT_LOG_FAIL ]]
then
  mv $DSPACE_IMPORT_LOG_FAIL ${DSPACE_IMPORT_LOG_FAIL}.old
fi

cd $IMPORTERSDIR
askme "$(pwd): about to split importers"

if [[ ${SPLIT:0:5} == "https" ]]
then
  # if it's a url, curl it, otherwise just execute it
  curl -s "$SPLIT" | bash -s || {
    echo "Batch-splitting importers failed"
    exit 1
  }
else
  sleep 30
  bash "$SPLIT" || {
    echo "Batch-splitting importers failed"
    exit 1
  }
fi
# To do: ANSIBLE copy scripts to dspace's $HOME, github hosted split.sh with curl

askme "Confriming dspace user shell access..."
# You can comment this line out if your sudo config doesn't allow for a grace period, causing you to authenticate manually twice
if ! sudo -v >/dev/null 2>/dev/null
then
  echo "sudo failure: make sure you're a sudoer, and your credentials are correct"
  #exit 1
fi

for batch in $IMPORTERSDIR/*
do
  DSPACE_IMPORT_LOG="/home/dspace/import-logs/$(basename $batch).log"
  if [[ ! -d $batch ]]
  then
    echo "Warning: file $batch found; skipping it, I expect importers to be directories." | tee $DSPACE_IMPORT_LOG_FAIL
  else
    echo "[$(date '+%x %X')] -- Using batch: $batch"
    askme "About to run dspace import. $EPERSON, $COLLECTION, $batch"
    #to do: query the db for this specific id before import, update sheets (auto mporei na ginei eite synolika sto upload.sh eite edw me ligo config)
    sudo -u dspace /opt/dspace/bin/dspace \
    import -a -e $EPERSON -c $COLLECTION -s "$batch" -m ~dspace/mapfiles/mapfile_$(basename $batch) -w \
    > $DSPACE_IMPORT_LOG
    if [[ $? -gt 0 ]]
    then
      echo "dspace import failed, skipping... $(date '+%x %X')"
      echo "[$(date '+%x %X')] FAILED: import $batch" >> $DSPACE_IMPORT_LOG_FAIL
    else
      echo "batch done! ($(basename $batch))"
      basename $batch >> $SUCCESSFUL
      zip -qr $ZIP $batch && rm -r $batch
    fi
  fi
done

sha256sum $ZIP >> ~dspace/importers-backup-integrity.txt
if [[ -f $DSPACE_IMPORT_LOG_FAIL && $(cat $DSPACE_IMPORT_LOG_FAIL | wc -l) -gt 0 ]]
then
  less $DSPACE_IMPORT_LOG_FAIL
fi
