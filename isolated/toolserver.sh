#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Launcher for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/toolserver.sql|toolserver.sql]]'''.
 # 
 # Works on the Toolserver and optputs server names by language.
 #
 # <pre>

#
# Later on this will be equal to $1, not for now.
#
# This variable here is just for the most stable of the servers.
#

language="ru"

#
# Indeed, when the language of interest is up, the most stable server is 
# that one, who runs it up. 
#
# Later could be changed to any other constant or chosen
# among the existent server list.
#
server=1

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

} | $( sql $server ) 2>&1

cat toolserver.sql | $( sql $server u_${usr}_golem_${language} ) 2>&1

#
# Which server language $1 database is located at?
#
echo "SELECT server_num( '$1' );" | $( sql $server u_${usr}_golem_${language} ) 2>&1

# </pre>
