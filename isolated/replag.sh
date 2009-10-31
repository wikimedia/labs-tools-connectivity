#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Launcher for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/replag.sql|replag.sql]]'''.
 # 
 # Works on the Toolserver and outputs the replag for language given.
 #
 # <pre>

#
# Wikipedia language
#
language="$1"

#
# Server for connection depends on the target language
#
server=$( ./toolserver.sh "$language" )

#
# Initialize variables: $dbserver, $dbhost, $usr.
#
# Creates sql( $server ) function.
#
source ../cgi-bin/ts $server

rm -f ${language}.debug.log ${language}.no_stat.log ${language}.no_templates.log no_mr.log

{
  #
  # New language database might have to be created.
  #
  echo "create database if not exists u_${usr}_golem_s${dbserver}_${language};"

} | $( sql $server ) 2>&1 | ./handle.sh

{
  cat toolserver.sql
  cat replag.sql
} | $( sql $server u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | ./handle.sh

#
# Time is the measure of change.
# What time is it? Now you know that, and this is a change for youself.
#
echo "CALL replag( '$language' );" | $( sql $server u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | ./handle.sh

# </pre>