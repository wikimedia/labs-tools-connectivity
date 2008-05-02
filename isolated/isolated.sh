 # 
 # Handler for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sql|isolated.sql]]'''.
 # 
 # Works on the Toolserver and outputs the processing results into a set
 # of files being switched by some API calls from '''isolated.sql'''.
 #
 # <pre>

#!/bin/bash

do_templates=0
do_stat=0
do_mr=0
if [ "$1" = "templates" ] || [ "$2" = "templates" ] || [ "$3" = "templates" ]
then
  do_templates=1
fi
if [ "$1" = "mr" ] || [ "$2" = "mr" ] || [ "$3" = "mr" ]
then
  do_mr=1
fi
if [ "$1" = "stat" ] || [ "$2" = "stat" ] || [ "$3" = "stat" ]
then
  do_stat=1
fi

dbhost="sql-s3"
dbhost2="sql-s2"
myusr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
sql="mysql --host=$dbhost -A --database=u_${myusr} -n -b -N --connect_timeout=10"
sql2="mysql --host=$dbhost2 -A --database=u_${myusr} -n -b -N --connect_timeout=10"

rm -f ./*.info ./*.txt ./*.stat debug.log no_stat.log no_templates.log no_mr.log stats_done.log

time { 
  # run to obtain all templates management data asap
  {
    cat disambig.sql
    cat iwikispy.sql
    cat cgi.sql

    echo "set @namespace=0;"

    #
    # Choose the maximal oscc size for namespace 0, note:
    #        - 5  takes up to 10 minutes,
    #        - 10 takes up to 15 minutes, 
    #        - 20 takes up to 20 minutes, 
    #        - 40 takes up to 25 minutes
    #        - more articles requires @@max_heap_table_size=536870912.
    #

    echo "set @max_scc_size=10;"

    #
    # Choose the right limit for recursion depth allowed.
    # Set the recursion depth to 255 for the first run
    # and then set it e.g. the maximal clusters chain length doubled.
    #

    echo "set max_sp_recursion_depth=10;"

    cat isolated.sql

    echo 'CALL doouter();'

    echo "set @namespace=14;"

    #
    # Namespace 14 can be fully thrown within 45 minutes,
    # the oscc size in this case is set to zero, which means no limit.
    #

    echo "set @max_scc_size=0;"

    #
    # Choose the right limit for recursion depth allowed.
    # Set the recursion depth to 255 for the first run
    # and then set it e.g. the maximal clusters chain length doubled.
    #

    echo "set max_sp_recursion_depth=255;"

#    echo "set @@max_heap_table_size=134217728;"
#    echo "set @@max_heap_table_size=268435456;"
#    echo "set @@max_heap_table_size=536870912;"
     echo "set @@max_heap_table_size=1073741824;"

    echo 'CALL connectivity();'

    echo 'CALL doouter();'

  } | $sql 2>&1 | ./handle.sh $1 $2 $3
}

# </pre>