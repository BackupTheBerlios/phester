#!/bin/bash
#
# phester.sh
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
#
# $Id: phester.sh,v 1.4 2002/05/02 09:03:42 riessen Exp $
#

#
# controller for the phester application.
#
# TODO: 1. problem if there are same named files in different library 
# TODO:    directories to which changes are made in a single run, then
# TODO:    the later change replaces the earlier one .....

# configuration file
# if there is an argument, assume it is the name of the configuration
# file to use
if (( $# > 0 ));
then
  CONFIG_FILE=$1
else
  CONFIG_FILE=phester.cfg
fi

# time to wait (seconds) for the execution of the unit tests, after this
# period, the process is assumed to have entered an endless loop
# and is killed.
wait_time=10

# PHP script to run all unit tests and whose output is becomes
# the protocol for the modification
run_all_tests=RunAllTests.php
run_all_tests_dir=/www/development/BerliOS/sourceagency.test/tests

# List of directories containing library code that can be 
# modified. The directories are separated using a colon (:)
lib_dirs=/www/development/BerliOS/sourceagency.test/include

# Colon separated list of file extensions that represent PHP code and 
# can therefore be modified. 
file_ext=inc:php:php3

# php interpretor to use
php_engine=php4

# output directory where information to all runs is stored. This directory
# is created if it does not already exist
output_dir=/www/phester/`date | sed s/\ /_/g | sed s/:/^/g`

# AWK script for making changes to a php file
script_changes=/www/development/utils/php/phester/php_changer.gawk
script_options="-f /www/development/utils/gawk/handle_command_line.gawk"

# maximum number of changes to make to a file when it is changed
num_changes=10
# this is the number of files to change before resetting the changes,
# note that after each file is changed, all the unit tests are called.
files_to_change=4

# gawk interpretor to use
gawk=gawk

# this is where the script writes information intended for immediate
# consumption by the user. To avoiding having any output, set this to
# /dev/null ...
STD_ERR=/dev/stderr

# source the configuration file if one exists
# all variables above this point are externally configurable, 
# all below aren't!
if [[ -f $CONFIG_FILE ]];
then
    . $CONFIG_FILE
    echo "Initialised from '"${CONFIG_FILE}"' ..." >> $STD_ERR
else
    echo "Configuration file '"${CONFIG_FILE}"' not found" >> $STD_ERR
fi

# this is a non-changable constant: base name of the file containing the
# the output of executing all unit tests
BASE_RAUT=run_all_unit_tests
# this is the extension files become when they are backed-up
ORIG=phester
# name of the file containing details of the last RAUT run
LAST_RAUT=_raut_last_run_

# we store the pid in this file
PID_FILE=/tmp/phester.pid
OUT_DIR_FILE=/tmp/phester.$$.sh
if [[ -f $PID_FILE ]];
then
    echo "PID File found, exiting ..." >> $STD_ERR
    exit
else
    echo "PID is: "$$
    echo $$ > $PID_FILE
    echo "output_dir="$output_dir > $OUT_DIR_FILE
fi

#
# declaration of required functions
#

# writes the most important configuration information to the 
# protocol
function dump_configuration() {
    echo "Output directory: " $output_dir >> $STD_ERR
    echo "Time to wait before killing execution ${wait_time} sec" >> $protocol
    echo "Change Configuration"                                   >> $protocol
    echo "  Files to change per run: " $files_to_change           >> $protocol
    echo "  Max number of changes made to file: " $num_changes    >> $protocol
    echo "Library configuration"                                  >> $protocol
    echo "  Library directory(s): " $lib_dirs                     >> $protocol
    echo "  File extensions of library files: " $file_ext         >> $protocol
    echo "Unit test configuration"                                >> $protocol
    echo "  Script directory: " $run_all_tests_dir                >> $protocol
    echo "  Script for running all unit tests: " $run_all_tests   >> $protocol
    echo "GAWK script for changing files: " $script_changes       >> $protocol
    echo "Output directory: " $output_dir                         >> $protocol
    echo "PHP Engine: " $php_engine                               >> $protocol
    echo "Standard error: " $STD_ERR                              >> $protocol
}

# generate a list of files that can be modified.
function generate_lib_file_list()
{
    for ext in `echo $file_ext | sed s/:/\ /g`;
    do
        for dir in `echo $lib_dirs | sed s/:/\ /g`;
        do
            for f in `ls ${dir}/*.${ext} 2> /dev/null`;
            do
                if [[ -f ${f}.${ORIG} ]];
                then
                    echo -n "WARNING: ignoring ${f} because a " >> $protocol
                    echo "phester original copy exists" >> $protocol
                else
                    lib_files[$lib_files_count]=$f
                    lib_files_count=$(($lib_files_count + 1))
                fi
            done
        done
    done
}

# randomly choose a file to be modified and modify that file
function make_change()
{
    file_name=${lib_files[$(($RANDOM % $lib_files_count))]}
    
    # .${ORIG} files are the original files that have not be modified
    if [[ ! -f ${file_name}.${ORIG} ]]; 
    then
        files_changed[$files_changed_count]=$file_name
        files_changed_count=$(($files_changed_count + 1))
        cp ${file_name} ${file_name}.${ORIG}
    fi

    echo "Making changes to $file_name"
    # call the script that makes the changes
    $gawk ${script_options} -f ${script_changes} --seed=$RANDOM \
                            --changes=$num_changes ${file_name} > /tmp/${$}.txt
    mv -f /tmp/${$}.txt ${file_name}
}

# reset all changes, i.e. move all .${ORIG} files back
function reset_changes()
{
    for f in ${files_changed[@]};
    do
        echo "Resetting changes made to " `basename ${f}`
        mv -f ${f}.${ORIG} ${f}
    done
    files_changed=()
    files_changed_count=0
}

# function called when specific signals are recieved
function stop_phestering() {
    echo "Recieved quit signal, exiting after run " $run_counter >> $protocol
    echo "Recieved quit signal, exiting after run " $run_counter >> $STD_ERR
    quit=0
}

function copy_changes_to_output_dir() {
    for f in ${files_changed[@]};
    do
      bname=`basename ${f}`
      echo "Diff'ing " ${bname} " and " ${bname}.${ORIG} >> $protocol
      # giving the -b (ignore changes to white space) stops the 
      # generation of diff files that only contain a notice to the fact
      # that there was no new line at the end of the file
      diff -b ${f}.${ORIG} ${f} > \
                          $output_dir/${bname}.${run_counter}.${change_num}
    done
}

function execute_unit_tests() {
    # argument: $1 is the output file
    currwd=`pwd`
    cd $run_all_tests_dir
    rm -fr $1
    $php_engine $run_all_tests > $1 &
    cd $currwd
}

function sleep_and_diff() {
    # assume that /tmp/$$ contains the output of the last run of the unit
    # tests and that $output_dir/${BASE_RAUT}.0.0 contains a copy
    # of the "perfect" run.
    sleep $wait_time
    if ps -p $! > /dev/null 2>&1;
    then
        echo "Process "$!" still running: Change: "${change_num} >> $protocol
    fi
    kill $! >> $protocol 2>&1

    if [[ -f $output_dir/${BASE_RAUT}.${run_counter}.${change_num} ]];
    then
        echo -n "**WARNING: ${BASE_RAUT}."           >> $protocol
        echo -n "${run_counter}.${change_num}  "     >> $protocol
        echo "existed, replacing it!"                >> $protocol
        rm -fr $output_dir/${BASE_RAUT}.${run_counter}.${change_num}
    fi

    # compare the outputs of the runs. The last output is compared to the
    # current output, if a difference is noticed, then a diff with the
    # *perfect* run is made (this is the only run that is kept), else
    # we touch the diff file to indicate no change happened.
    if ! diff -q /tmp/$$ $output_dir/$LAST_RAUT >/dev/null; 
    then
        diff $output_dir/${BASE_RAUT}.0.0 /tmp/$$ > \
                         $output_dir/${BASE_RAUT}.${run_counter}.${change_num}
    else
        touch $output_dir/${BASE_RAUT}.${run_counter}.${change_num}
    fi

    # make a copy of the output of the last RAUT run
    rm -f $output_dir/$LAST_RAUT
    cp /tmp/$$ $output_dir/$LAST_RAUT
}

function do_run() {
    while (( $change_num < $files_to_change ));
    do
        echo -n "," $change_num >> $STD_ERR
        make_change >> $protocol
        copy_changes_to_output_dir 
        execute_unit_tests /tmp/$$
        sleep_and_diff
        change_num=$(($change_num + 1))
    done
    reset_changes >> $protocol
}

#
# let's start phestering .....
#
declare -a lib_files[0] files_changed[0]
lib_files_count=0
run_counter=0
files_changed_count=0

# intialise the output directory
if [[ -f $output_dir ]];
then
    # to be sure ... to be sure
    rm -fr $output_dir
    rm -fr $output_dir
fi
if [[ ! -d $output_dir ]];
then
    mkdir -p $output_dir
fi

# initialise the protocol
protocol=$output_dir/phester.protocol
touch $protocol
echo "Starting on: " `date` >> $protocol

generate_lib_file_list

# to stop the phestering, send signal 30
trap stop_phestering SIGUSR1 SIGINT SIGTERM SIGHUP

dump_configuration

quit=1
run_counter=0
change_num=0

# create a "perfect" run with which we do a diff to find differences
# need to wait and check that it was completed, if not then exit with
# error message
echo "Creating \"perfect\" unit test run: "$output_dir/${BASE_RAUT}.0.0
echo "Creating unit test run: "$output_dir/${BASE_RAUT}.0.0 >> $protocol
execute_unit_tests $output_dir/${BASE_RAUT}.0.0
sleep $wait_time

if ps -p $! >/dev/null 2>&1;
then
    echo "It appears that the unit tests contain an endless loop ... exiting"
    echo "Failed to create clean unit test run" >> $protocol
    echo "Finishing on: " `date` >> $protocol
    rm --force --recursive $output_dir $PID_FILE $OUT_DIR_FILE
    # sometimes SuSE is just plan f**ked in the head: rm complains although
    # the directory is emptied by the command, so we need to call again
    # to remove a *now* empty directory
    rm --force --recursive $output_dir $PID_FILE $OUT_DIR_FILE
    exit 1
fi

# create the first last raut file ...
rm -f $output_dir/$LAST_RAUT
cp $output_dir/${BASE_RAUT}.0.0 $output_dir/$LAST_RAUT

run_counter=1
while (( $quit ));
do
    echo "--------------- Run: " $run_counter " ---------------" >> $protocol
    echo -en "\n Doing run " $run_counter " change: " >> $STD_ERR
    change_num=0
    do_run >> $protocol
    run_counter=$(($run_counter + 1))
done

# remove the PID file so that other phesters may start
# paranoid test: check that the pid contained in PID_FILE is the 
# same as our pid. 
rm -fr $PID_FILE $output_dir/$LAST_RAUT

# all changes should have been resetted
echo -e "\n\n" >> $STD_ERR
echo "Finishing on: " `date` >> $protocol
