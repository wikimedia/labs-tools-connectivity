#!/bin/bash

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

echo 'SELECT CONCAT( ":: echo . ", count(*), " items received" ) FROM '"$1"';'
