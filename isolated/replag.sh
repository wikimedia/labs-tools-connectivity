#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Launcher for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/replag.sql|replag.sql]]'''.
 # 
 # Works on the Toolserver and outputs the replag for language given.
 #
 # <pre>

#
# This variable here is only for values logging. 
# Currently all replag measurements are being stored in ru and this behaviour
# could be changed when more language databases occur or on any other
# interest.
#
# The language for replag calculation is completely different
# and being reffered below in code as $1.
#
language="ru"

#
# Server for connection depends on the target language
#
server=$( ./toolserver.sh "$1" )

#
# Initialize variables: $dbserver, $dbhost, $usr.
#
# Creates sql( $server ) function.
#
source ../cgi-bin/ts $server

rm -f debug.log no_stat.log no_templates.log no_mr.log

{
  #
  # New language database might have to be created.
  #
  echo "create database if not exists u_${usr}_golem_${language};"

} | $( sql $server ) 2>&1 | ./handle.sh

{
  cat toolserver.sql
  cat replag.sql
} | $( sql $server u_${usr}_golem_${language} ) 2>&1 | ./handle.sh

#
# Time is the measure of change.
# What time is it? Now you know that, and this is a change for youself.
#
echo "CALL replag( '$1' );" | $( sql $server u_${usr}_golem_${language} ) 2>&1 | ./handle.sh

# </pre>