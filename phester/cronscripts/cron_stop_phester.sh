#!/bin/bash
#
# cron_stop_phester.sh
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
#
# $Id: cron_stop_phester.sh,v 1.2 2002/05/02 09:04:19 riessen Exp $
#

PID_FILE=/tmp/phester.pid
PHESTER_HOME=/home/users/riessen/bin/phester
GAWK_ENGINE=/home/users/riessen/bin/gawk

echo "This is file "$0
echo "PID is: "$$

# first ensure that the pid file exists ...
if [[ ! -f $PID_FILE ]]; 
then
  echo "No pid file found, exiting ..."
  exit 1
fi

# check whether there is a phester running under the pid ....
P_PID=`cat $PID_FILE`
if ! ps -p $P_PID | grep phester >/dev/null 2>&1;
then
  echo "It appears phester with pid " $P_PID "isn't running"
  rm -fr ${PID_FILE}
  exit 1
fi

# right, now kill the running phester
echo "Sending phester with pid="$P_PID" signal to stop ..."
kill -SIGHUP $P_PID

# wait a maximum of 5 minutes for the phester to stop
counter=0
while ps -p $P_PID | grep phester >/dev/null 2>&1;
do
  echo -n "."
  sleep 5
  counter=$(($counter + 1))
  if (( $counter > 60 ));
  then
    break;
  fi
done
echo ""

# if phester is still running, then bad luck, we're outta here
if ps -p $P_PID | grep phester >/dev/null 2>&1;
then
  echo "It appears phester with pid " $P_PID " won't stop"
  exit 1
fi

# now we're ready to do something useful, phester has stopped (and was
# running) ... we can now create the html files
# get the output directory
if [[ -f /tmp/phester.$P_PID.sh ]]; 
then
  # this defines the output_dir variable
  echo "Sourcing /tmp/phester.$P_PID.sh ..."
  . /tmp/phester.$P_PID.sh
  rm -fr /tmp/phester.$P_PID.sh
else
  echo "Unable to obtain the output directory"
  exit 1
fi

echo "cd'ing to "$output_dir
cd $output_dir

echo "It appears phester has completed, building summary information ...."
$GAWK_ENGINE -f $PHESTER_HOME/utilities.gawk \
             -f $PHESTER_HOME/handle_command_line.gawk \
             -f $PHESTER_HOME/format_results.gawk \
             --gawk=$GAWK_ENGINE --lib=$PHESTER_HOME \
             phester.protocol

echo "Creating tar file ..."
cd ..
bname=`basename $output_dir`
tar cfz ${bname}.tgz ${bname}
rm -rf ${bname}

# done.

