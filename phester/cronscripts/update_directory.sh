#!/bin/bash
#
# update_directory.sh
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
#
# $Id: update_directory.sh,v 1.6 2002/05/29 10:35:57 riessen Exp $
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
# how many tar files should be kept, this number must be greater
# than STORE_LAST
TAR_FILES_KEEP=5

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
    if [ -f ${SRC_DIR}/${tfile}.tgz ];
    then
      tar xfz ${SRC_DIR}/${tfile}.tgz
      if [ -d $tfile ];
      then
        cd $tfile
        echo -n " removing zero-sized files ... "
        file_list=`ls -S -s -1 | grep "^[ ]*0[ ]" | sed s"/[ ]*0[ ]//"g`
        rm -fr $file_list
        cd ..
      else
        echo -n " directory '"${tfile}"' was not created ..."
      fi
    else
      echo -n " does not exist ... "
      if [ -d ${SRC_DIR}/${tfile} ];
      then
        echo -n " removing directory ${SRC_DIR}/${tfile} ... "
        rm -fr ${SRC_DIR}/${tfile}
      fi
    fi
    echo "done"
done

echo "Recreating index.html ..."
cd $DEST_DIR
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

# remove the excessive tar files in the source directory
remove_file_count=$(( `ls | wc -l` - $TAR_FILES_KEEP ))
echo "Removing last $remove_file_count files ..."
for n in `ls --sort=time | tail -$remove_file_count`; 
do
    echo "  removing $n ..."
    rm -f $n
done

# clean up after ourselves
rm -fr $dir_list $tar_list

