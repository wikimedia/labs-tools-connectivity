#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]]
 #
 # Launcher for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/toolserver.sql|toolserver.sql]]'''.
 # 
 # Works on the Toolserver and optputs server names by language.
 #
 # <pre>

#
# Wikipedia language
#
language="$1"

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

  echo "use u_${usr}_golem_p;"

  if [ "$2" != 'skip_infecting' ]
  then
    cat toolserver.sql
  fi

  #
  # Which server the $language database is located at?
  #
  echo "SELECT server_num( '$language' );"

} | $( sql $server ) 2>&1

# </pre>
