#!/bin/bash
#
# cron_start_phester.sh
#
# Author: Gerrit Riessen, gerrit.riessen@open-source-consultants.de
# Copyright (C) 2002 Gerrit Riessen
# This code is licensed under the GNU Public License.
#
# $Id: cron_start_phester.sh,v 1.1 2002/02/20 16:02:55 riessen Exp $
#

HOME_DIR=/home/users/riessen
TEST_REPO_HOME=${HOME_DIR}/sourceagency.phester
PHESTER_HOME=${HOME_DIR}/bin/phester
STD_ERR=/tmp/phester.out.$$
# this is the location of phpunit.php and is used by constants.php
PHP_LIB_DIR=/home/users/riessen/lib/php
export PHP_LIB_DIR

CONFIG_FILE=phester_`hostname`.cfg

echo "This file is "$0

# first update the repo on which phester will work
cd $TEST_REPO_HOME
echo "Updating phester repository in "$TEST_REPO_HOME
cvs update -d

# change to the phester home and create a new configuration file
echo "cd'ing to" $PHESTER_HOME
cd $PHESTER_HOME

if [[ -f $CONFIG_FILE ]]; 
then
   mv -f $CONFIG_FILE ${CONFIG_FILE}.orig
fi

cat>$CONFIG_FILE<<EOF
#
# Don't edit, automatically generated
# See: $0 for details
#
phester_home=${PHESTER_HOME}

num_changes=40
files_to_change=5
script_changes=\${phester_home}/php_changer.gawk
script_options="-f \${phester_home}/handle_command_line.gawk"
output_dir=\${phester_home}/_output_/\`date | sed s/\ /_/g | sed s/:/^/g\`
run_all_tests_dir=${TEST_REPO_HOME}/tests
lib_dirs=${TEST_REPO_HOME}/include
php_engine=php
gawk=${HOME_DIR}/bin/gawk
STD_ERR=${STD_ERR}
EOF

touch $STD_ERR

./phester.sh $CONFIG_FILE

cat $STD_ERR
rm -fr $STD_ERR
