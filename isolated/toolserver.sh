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
language_sql=${language//\-/_}

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
  #
  # New language database might have to be created.
  #
  echo "create database if not exists u_${usr}_golem_s${dbserver}_${language_sql};"

} | $( sql $server ) 2>&1

cat toolserver.sql | $( sql $server u_${usr}_golem_s${dbserver}_${language_sql} ) 2>&1

#
# Which server the $language database is located at?
#
echo "SELECT server_num( '$language' );" | $( sql $server u_${usr}_golem_s${dbserver}_${language_sql} ) 2>&1

# </pre>
