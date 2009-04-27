#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Purpose: Data transmitter between different sql servers.
 #
 #          Gets input data stream from stdin, splits it into portions of
 #          reasonable size (8192 records for now) and passes to stdout as
 #          INSERT request to a table on receiving side with a name given
 #          by first command line argument.
 #
 #          Reports on completion to communtication_exchange table on receiving
 #          side and to stdout.
 # 
 # Use: Not for direct use, called from handle.sh as a result of a command like
 #      coming from a sender.
 #
 #      SELECT ':: <sender-server> give <data selection statement>';
 #
 #      Requires receiver to be prepared with use of a command like
 #
 #      SELECT ':: <receiver-server> take <table-name>';
 #
 #      Allowed values for <sender-server> and <receiver-server> are: s<1-3>.
 #

iter=0
portion=0;

while read line
do
  portion=$(($portion+8192))

  echo "INSERT INTO $1 VALUES "
  echo -e "$line"
  iter=$(($iter+1))
  while read line
  do
    echo -e ",$line"
    iter=$(($iter+1))
    if [ $iter -eq $portion ]
    then
      break
    fi
  done
  echo ';'
  sync
done
# this indicates the transfer is done
echo "INSERT INTO communication_exchange VALUES (1);";

echo "SELECT CONCAT( \":: echo . \", count(*), \" s$2 items received at s$3\" ) FROM $1;"
