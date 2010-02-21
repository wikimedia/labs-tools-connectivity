#!/bin/bash
 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Purpose: 
 #
 #      Packet run of connectivity analysis for various lanuages
 #      defined in a file, which name is passed here as an input parameter
 #
 # Error handling:
 #
 #      See <lang>.debug.log if created or the last file modified.
 #      See <lang>.log for the copy of stdout for each language processed
 #
 # <pre>



#
# Later could be changed to any other constant or chosen
# among the existent server list.
#
server=3

#
# Initialize variables: $dbserver, $dbhost, $usr.
#
# Creates sql( $server ) function.
#
source ../cgi-bin/ts $server

{
  echo "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;"

  #
  # New language database might have to be created.
  #
  echo "create database if not exists u_${usr}_golem_p;"

  #
  # Switch to the language database just created.
  #
  echo "use u_${usr}_golem_p;"

  cat toolserver.sql

  #
  # Once the processing is started, every server should have capabilities
  # to support web-server.
  #
  echo "CALL project_for_everywhere();"

} | $( sql $server ) 2>&1 | ./handle.sh $cmdl

#
# Read language configuration file and run the analysis for each
# language defined there.
#
while read line
do
  sline=( $line )

  #
  # Ignore commented and empty lines
  #
  if [ "$line" != '' ] && [ ${line:0:1} != '#' ] && [ ${line:0:1} != ' ' ]
  then
    ./isolated.sh $line | tee ${sline[0]}.log
  fi
done < $1

# </pre>
