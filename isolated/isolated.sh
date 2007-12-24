 # 
 # Handler for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sql|isolated.sql]]'''.
 # 
 # Works on the Toolserver and outputs the processing results into a set
 # of files being switched by some API calls from '''isolated.sql'''.
 #
 # <pre>

#!/bin/bash

# set the maximal replication lag value in minutes, which is allowed for apply
# probably, less than script actually works
maxlag=10

do_apply=0
if [ "$1" = "apply" ]
then
  do_apply=1
fi

dbhost="sql-s3"
myusr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
mypwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=$dbhost -A --user=${myusr} --password=${mypwd} --database=u_${myusr} -n -b -N"

ruusr=$( cat ~/.ru.cnf | grep 'user ' | sed 's/^user = \"\([^\"]*\)\"$/\1/' )
rupwd=$( cat ~/.ru.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )

rm -f ./*.info ./*.txt ./*.stat debug.log

out='';
handle ()
{
  local line=$1
  local replag=''

  if [ "${line:0:3}" = ':: ' ]
  then
    # apply previous command if necessary
    if [ "$state" = '2' ]
    then
      if [ "$do_apply" = "1" ]
      then
        echo $collectedline | perl r.pl $outpage "$ruusr" "$rupwd" 'pre'
      fi
    fi
    state=0
    # recognize current command
    if [ "${line:3:5}" = 'echo ' ]
    then
      echo ${line:8}
    else
      if [ "${line:3:7}" = 'replag ' ]
      then
        echo replag: ${line:10}
        if [ "$do_apply" = "1" ]
        then
          replag=${line:10};
          hours=${replag%:*}
          minutes=${hours#*:}
          minutes=`expr $minutes + 0`
          hours=${hours%:*}
          hours=`expr $hours + 0`
          minutes=$[$minutes+60*$hours]
          if [ $minutes -ge $maxlag ]
          then
            echo replag of $minutes minutes is to big, must be below $maxlag
            echo nothing will be applied
            do_apply=0
          fi
        fi
      else
        if [ "${line:3:4}" = 'out ' ]
        then
          out=${line:7}
          state=1 # file output
          if [ ! -f $out ]
          then
            echo -ne \\0357\\0273\\0277 > $out
           fi
        else
          if [ "${line:3:7}" = 'upload ' ]
          then
            out=${line:10}
            state=2 # upload and file output
            collectedline=''
            # need better way for url definition, maybe sql driven
            outpage=${out:15:2}
            if [ ! -f $out ]
            then
              echo -ne \\0357\\0273\\0277 > $out
            fi
          fi
        fi
      fi
    fi
  else
    case $state in           # Can't connect to MySQL server on '$dbhost' (111)'
    0) if [ "${line:0:20}" = 'ERROR 2003 (HY000): ' ]
       then
         echo $dbhost is unavailable
       else
         if [ "$line" != '' ]
         then
           echo -ne $line\\r\\n >> debug.log
         fi
       fi;;
    1) echo -ne $line\\r\\n >> $out
       ;;
    2) echo -ne $line\\r\\n >> $out
       collectedline=$(echo -ne "${collectedline}\\r${line}")
       ;;
    *) echo $line;;
    esac
  fi
}

time { 
  {
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

  } | $sql 2>&1 | { 
                    state=0
                    while read -r line
                      do handle "$line"
                    done
                    if [ "$do_apply" = "1" ]
                    then
                      # cut three very first utf-8 bytes
                      tail --bytes=+4 ./*.stat | perl r.pl 'stat' "$ruusr" "$rupwd" 'stat'
                    fi
                  }

  rm -f today.7z
  7z a today.7z ./*.txt >7z.log 2>&1
  rm -f ./*.txt

  rm -f info.7z
  7z a info.7z ./*.info >>7z.log 2>&1
  rm -f ./*.info

  7z a stat.7z ./*.stat >>7z.log 2>&1

  todos 7z.log

  {
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

    cat isolated.sql

  } | $sql 2>&1 | { 
                    state=0
                    while read -r line
                      do handle "$line"
                    done
                  }
}

# </pre>