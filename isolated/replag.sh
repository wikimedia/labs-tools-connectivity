#!/bin/bash
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Launcher for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/replag.sql|replag.sql]]'''.
 # 
 # Works on the Toolserver and outputs the replag for s3.
 #
 # <pre>

dbhost="sql-s3"
myusr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
sql="mysql --host=$dbhost -A --database=u_${myusr} -n -b -N --connect_timeout=10"

cat replag.sql | $sql 2>&1 | ./handle.sh

#
# Time is going and changes are required.
#
echo "CALL replag();" | $sql 2>&1 | ./handle.sh

# </pre>