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
added="${added}\nalter table language_stats drop primary key;"
added="${added}\nalter table language_stats add primary key (lang, ts);"
added="${added}\nalter table language_stats drop column article_diff;"
added="${added}\nalter table language_stats drop column isolated_diff;"
added="${added}\nalter table language_stats drop column creator_diff;"
added="${added}\nalter table language_stats drop column disambig_diff;"
added="${added}\nalter table language_stats drop column drdi_diff;"
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
                          'en', 1, 3215609, 0, 179509, 157278,
                          3007, 8076, 8.530, 281, 4005, 83429,
                          '2010-08-05 14:47:02', 1, 0
                        );"
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
                          'en', 1, 3247083, 0, 181122, 156380,
                          2998, 9215, 8.310, 235, 4073, 83343,
                         '2010-09-05 16:28:55', 1, 293586
                        );"

echo -e $added | $( sql 1 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 2 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 3 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

# </pre>
