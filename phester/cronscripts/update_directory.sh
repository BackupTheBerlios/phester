#!/bin/bash
#
# update_directory.sh
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
#
# $Id: update_directory.sh,v 1.3 2002/03/07 14:40:33 riessen Exp $
#
#
# utility script for taking the latest phester output tar (generated
# by cron_stop_phester.sh) and installing it into a specific directory.
#

# this contains the phester output subdirectories and an index.html
DEST_DIR=/home/groups/sourceagency/htdocs/phester
# src directory contains the phester output tar's
SRC_DIR=/home/users/riessen/bin/phester/_output_
# how many phester outputs to store in the destination directory (in the
# interests of saving space, this should be under 10)
STORE_LAST=3

echo "This file is "$0
echo "Destination dir="$DEST_DIR
echo "Source Directory="$SRC_DIR

tar_list=/tmp/ud_dl_tars_$$.txt
dir_list=/tmp/ud_dl_dirs_$$.txt
rm -fr $dir_list $tar_list $DEST_DIR/index.html

# first find out which files are the most up-to-date
cd $SRC_DIR
ls --sort=time | sed s/[.]tgz$//g | head -${STORE_LAST} | sort > $tar_list

# now find out which files we can delete
cd $DEST_DIR
ls | sort > $dir_list

echo "Removing old directories:"
for dir in `diff -u $dir_list $tar_list | grep ^-[^-] | sed s/^-//g`; 
do
    echo "  "$dir
    rm -fr $dir
done

echo "Adding new directories ..."
for tfile in `diff -u $tar_list $dir_list | grep ^-[^-] | sed s/^-//g`;
do
    echo -n "  "${tfile}.tgz
    tar xfz ${SRC_DIR}/${tfile}.tgz
    cd $tfile
    echo -n " removing zero-sized files ..."
    file_list=`ls --sort=size -s -1 | grep "^[ ]*0[ ]" | sed s"/[ ]*0[ ]//"g`
    rm -fr $file_list
    cd ..
    echo "done"
done

echo "Recreating index.html ..."
file_list=`ls`
echo "<html><head><title>Phester Index</title></head><body><ul>" > index.html
for dir in $file_list;
do
    datum=`echo $dir | sed s"/_/ /"g | sed s"/\^/:/"g`
    echo "<li>For "${datum}" <ul>"                        >> index.html
    echo "<li><a href=\"${dir}/results.files.html\">Results by Files</a>" \
                                                          >> index.html
    echo "<li><a href=\"${dir}/results.runs.html\">Results by Runs</a>" \
                                                          >> index.html
    echo "</ul>"                                          >> index.html
done

echo "</ul></body></html>" >> index.html

# clean up after ourselves
rm -fr $dir_list $tar_list

