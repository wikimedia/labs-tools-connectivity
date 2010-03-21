#!/bin/bash
 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: Upgrade shared data format from ver 440 to upper
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
added="${added}\nalter table language_stats add column disambig_recognition TINYINT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column article_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column chrono_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column disambig_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column isolated_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column creator_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column deadend_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column nocat_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column drdi REAL(5,3) NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column nocatcat_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column catring_count INT UNSIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column article_diff INT SIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column isolated_diff INT SIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column creator_diff INT SIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column disambig_diff INT SIGNED NOT NULL DEFAULT '0';"
added="${added}\nalter table language_stats add column drdi_diff REAL(5,3) NOT NULL DEFAULT '0';"

echo -e $added | $( sql 1 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 2 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

echo -e $added | $( sql 3 u_${usr}_golem_p ) 2>&1 | ./handle.sh $cmdl

# </pre>
