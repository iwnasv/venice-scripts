#!/bin/bash
# expects count-items.py in $PATH
# source this script so it doesn't kill the whole process when it exits

while getopts "q" opt
do
  case $opt in
    q)
      alias echo="true" ;; # quiet option; mute echo for use in scripts
  esac
done

if [[ -z $1 ]]
then
  echo "importer validator called with no arguements; exiting"
  exit 1
fi
if [[ $(count-items.py "$1") -ne 0 ]]
then
  echo "WARN: duplicate importer encountered"
  exit 1
fi
exit 0