#!/bin/bash
 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: Upgrade shared data format from ver 456 to an upper
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
added="${added}\ninsert ignore into language_stats ( lang,
                                                     disambig_recognition,
                                                     article_count,
                                                     chrono_count,
                                                     disambig_count,
                                                     isolated_count,
                                                     deadend_count,
                                                     nocat_count,
                                                     drdi,
                                                     nocatcat_count,
                                                     catring_count,
                                                     creator_count,
                                                     ts,
                                                     cluster_limit,
                                                     proc_time
                                                   )
                 values (
                          'en', 1, 3494365, 0, 195860, 163141,
                          1568, 2671, 6.274, 245, 4610, 84678,
                          '2011-06-19 19:29:18', 1, 150676
                        );"

echo -e $added | $( sql 1 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 2 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 3 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 6 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 7 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

# </pre>
