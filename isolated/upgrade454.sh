#!/bin/bash
 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: Upgrade shared data format from ver 449 to upper
 #
 # Use: Run once and destroy
 #
 # <pre>

#
# Initialize variables: $dbserver, $dbhost, $usr.
#
# Creates sql( $server ) function.
#
source ../cgi-bin/ts $server

added=''
added="${added}\nalter table language_stats add column cluster_limit INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column proc_time INT UNSIGNED NOT NULL DEFAULT '0';"

echo -e $added | $( sql 1 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 2 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 3 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

# </pre>
