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
# Bot may exit due to an error or be stopped manually.
# For both cases, once it was run again, no reason to keep it to be stopped.
#
rm -f ./stop.please

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

  cat toolserver.sql | sed -e 's/#.*//' -e 's/[ ^I]*$//' -e '/^$/ d'

  #
  # Once the processing is started, every server should have capabilities
  # to support web-server.
  #
  echo "CALL project_for_everywhere();"

} | $( sql $server ) 2>&1 | ./handle.sh $cmdl

count=0

#
# Read language configuration file and run the analysis for each
# language defined there.
#
# For host-oriented lists:
# select wiki.lang
#        from toolserver.wiki,
#             u_mashiah_golem_p.server
#        where is_closed=0 and
#              family='wikipedia' and
#              domain is not null and
#              server=sv_id
#              and host_name="$line";
#
# ORDER BY previous processing time is desired.
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

    # sometimes sql servers could be busy, so we just repeat
    while [ -f ${sline[0]}.repeat.please ]
    do
      rm -f ./${sline[0]}.repeat.please
      echo "REPEAT FOR ${sline[0]}"
      ./isolated.sh $line | tee ${sline[0]}.log
    done

    count=$((count+1))
  fi

  if [ -f ./stop.please ]
  then
    echo "Golem recognized a polite request for processing interruption"
    exit 0
  fi

done < $1

if [ "$count" = '0' ]
then
  echo "Golem found an empty script and has nothing to process"
fi

# </pre>
