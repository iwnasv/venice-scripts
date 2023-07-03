#!/bin/bash
# USAGE: Not much to do, you just call the script this time
# It expects ~dspace to have the importers and mapfiles directories

# Venice defaults
COLLECTION="a81650e4-a549-4d3c-8576-72d0e5820d51"
EPERSON="info@ie.org"
SPLIT="https://github.com/iwnasv/venice-scripts/raw/main/split.sh"
IMPORTERSDIR=~dspace/importers

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

if [[ -f  $IMPORTERSDIR/batch-archive.zip ]]
then
  echo "OLD: $(sha256sum -z $IMPORTERSDIR/batch-archive.zip).old" > ~dspace/importers-backup-integrity.txt
  date "+%x %X" >> ~dspace/importers-backup-integrity.txt
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
  bash "$SPLIT" || {
    echo "Batch-splitting importers failed"
    exit 1
  }
fi
# To do: ANSIBLE copy scripts to dspace's $HOME, github hosted split.sh with curl

askme "Confriming dspace user shell access..."
# You can comment this line out if your sudo config doesn't allow for a grace period, causing you to authenticate manually twice
if ! sudo -u dspace -v >/dev/null &2>1
then
  echo "sudo failure: make sure dspace user is present on the system, you're a sudoer, and your credentials are correct"
  exit 1
fi

for batch in $IMPORTERSDIR/*
do
  if [[ ! -d $batch ]]
  then
    if [[ $(basename $batch) != "batch-archive.zip" ]]
    then
      echo "Warning: file $batch found; skipping it, I expect importers to be directories."
    fi
  else
    DSPACE_IMPORT_LOG="$IMPORTERSDIR/../import-logs/$(basename $batch).log" #this is far from great but it does our job
    #you may manually need to change the directory here to fit another project in the future. I'd rather not add more parameters...
    echo $(date '+%x %X') -- Using batch: $batch, writing mapfile: ~dspace/mapfiles/mapfile_$(basename $batch), log: $DSPACE_IMPORT_LOG
    askme "About to run dspace import. $EPERSON, $COLLECTION, $batch"
    sudo -u dspace /opt/dspace/bin/dspace \
    import -a -e $EPERSON -c $COLLECTION -s "$batch" -m ~dspace/mapfiles/mapfile_$(basename $batch) -w \
    > $DSPACE_IMPORT_LOG && {
      # test me
      python3 setValues.py --project 'venetia' --items $(ls -1q $batch) --uploaded True
    } || {
      echo "dspace import failed, quitting... $(date '+%x %X')"
      exit 1
    }
    echo "batch done!"
    zip -jqr $IMPORTERSDIR/batch-archive.zip $batch/ && rm -r $batch
    #   ^ no leading directories (/home/dspace/...), quiet output, recursive
  fi
done

sha256sum $IMPORTERSDIR/batch-archive.zip >> ~dspace/importers-backup-integrity.txt
