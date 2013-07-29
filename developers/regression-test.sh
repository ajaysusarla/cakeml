#!/bin/bash

cd $(dirname "$0")/..

case $(uname -a) in
    Linux* ) TIMECMD="/usr/bin/time -o timing.log -f 'User:%U Mem:%M'";;
esac

while read i
do
  if [ ! -d $i ]
  then
      echo "Ignoring non-existent directory $i"
      continue
  fi
  pushd $i > /dev/null 2>&1
  /bin/rm -f timing.log 2> /dev/null
  Holmake cleanAll &&
  if eval $TIMECMD Holmake > regression.log 2>&1
  then
      echo -n "OK: $i"
      if [ -f timing.log ]
      then
          echo -n " -- " ; cat timing.log
      else
          echo
      fi
  else
      echo "FAILED: $i"
      exit 1
  fi
  popd > /dev/null 2>&1
done < developers/build-sequence
