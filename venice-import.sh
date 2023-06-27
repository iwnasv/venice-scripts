#!/bin/bash
# USAGE: Not much to do, you just call the script this time
# It expects ~dspace to have the importers and mapfiles directories

# Venice defaults
COLLECTION="a81650e4-a549-4d3c-8576-72d0e5820d51"
EPERSON="info@ie.org"
SPLIT_URL="https://github.com/iwnasv/venice-scripts/raw/main/split.sh"

askme () {
    if [[ -n $ASKME ]]
    then
      echo "$1"
      echo "Press enter to continue or ctrl+c to quit"
    fi
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
    h)
      echo "$(basename $0): Project data dspace import"
      echo "Usage: $(basename $0) [-c COLLECTION] [-e E-PERSON] [-p DSPACE_UNIX_USER_PASSWORD] [-C]"
      echo "-C asks for confirmation each time before doing anything important, -p is there for testing and possible future automations"
      ;;
  esac
done

if [[ ! -d ~dspace/importers || ! -d ~dspace/mapfiles ]]
then
  echo "This script expects the importers and mapfiles directories present under ~dspace and writable by the dspace user."
  exit 1
fi

cd ~dspace/importers
askme "$pwd: about to split importers"
split.sh || ../split.sh || curl -s https://github.com/iwnasv/venice-scripts/raw/main/split.sh | bash -s
# To do: ANSIBLE copy scripts to dspace's $HOME, github hosted split.sh with curl
if [[ $? -ne 0 ]]
then
  echo "Batch-splitting importers failed!"
  exit 1
fi

echo "Confriming dspace user shell access..."
# You can comment this line out if your sudo config doesn't allow for a grace period, causing you to authenticate manually twice
sudo -u dspace true
if [[ $? -ne 0 ]]
then
  echo "sudo failure: make sure dspace user is present on the system, you're a sudoer, and your credentials are correct"
fi
for batch in ~dspace/importers/*
do
  if [[ ! -d $batch ]]
  then
    echo "Warning: innappropriate file $batch found; skipping it."
  else
    DSPACE_IMPORT_LOG="~dspace/importers/$(basename $batch).log"
    echo $(date '+%x %X') Using batch: $batch, writing mapfile: ~dspace/mapfiles/mapfile_$(basename $batch), log: $DSPACE_IMPORT_LOG
    askme "About to run dspace import. $EPRESON, $COLLECTION, $batch"
    sudo -u dspace /opt/dspace/bin/dspace import -a -e $EPERSON -c $COLLECTION -s "$batch" -m ~dspace/mapfiles/mapfile_$(basename $batch) -w > $DSPACE_IMPORT_LOG
    if [[ $? -ne 0 ]]
    then
      echo "dspace import failed, quitting... $(date '+%x %X')"
    else
      echo "batch done!"
    fi
  fi
done
