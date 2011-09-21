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

{
  echo "SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;"

  echo "use u_${usr}_golem_p;"

  cat toolserver.sql replag.sql | sed -e 's/#.*//' -e 's/[ ^I]*$//' -e '/^$/ d'

  #
  # Time is the measure of change.
  # What time is it? Now you know that, and this is a change for youself.
  #
  echo "CALL replag( '$language' );"

} | $( sql $server ) 2>&1 | ./handle.sh $language

# </pre>
