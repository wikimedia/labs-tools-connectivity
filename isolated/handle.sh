#!/bin/bash

# set the maximal replication lag value in minutes, which is allowed for apply
# probably, less than script actually works
maxlag=10
# upload stat if replication time changed to last upload no less than 
# statintv minutes
statintv=720

do_templates=0
do_stat=0
do_mr=0
cmdl="$1 $2 $3"
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

extminutes ()
{
  local given=$1
  local hours=''
  minutes=''

  hours=${given%:*}
  minutes=${hours#*:}
  minutes=`expr $minutes + 0`
  hours=${hours%:*}
  hours=`expr $hours + 0`

  minutes=$[$minutes+60*$hours]
}

state=0
out='';
handle ()
{
  local line=$1
  local statlast='';

  if [ "${line:0:3}" = ':: ' ]
  then
    # apply previous command if necessary
    if [ "$state" = '2' ]
    then
      if [ "$do_mr" = "1" ]
      then
        if [ -f no_mr.log ]
        then
          do_mr=0
        else
          elem=${#collection[*]}
          {
            iter=0
            while [ $iter -lt $elem ]
            do
              echo ${collection[$iter]}
              iter=$(($iter+1))
            done
            sync
          } | perl mr.pl &
          unset collection
        fi
      fi
    fi

    # now start new command parse
    state=0
    # recognize current command
    if [ "${line:3:5}" = 'echo ' ]
    then
      echo ${line:8}
    else
      if [ "${line:3:7}" = 'replag ' ]
      then
        echo replag: ${line:10}
        if [ "$do_templates" = "1" ]
        then
          extminutes ${line:10}
          if [ $minutes -ge $maxlag ]
          then
            echo replag of $minutes minutes is to big, must be below $maxlag
            echo perishable data will not be applied
            do_templates=0
            echo "$do_templates" > no_templates.log
          fi
        fi
        sync
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
            # need better way for url definition, maybe sql driven
            outpage=${out:15:2}
            if [ ! -f $out ]
            then
              echo -ne \\0357\\0273\\0277 > $out
            fi
          else
            if [ "${line:3:5}" = 'stat ' ]
            then
              echo time since last stat upload: ${line:8}
              if [ "$do_stat" = "1" ]
              then
                if [ -f no_stat.log ]
                then
                  do_stat=0
                else
                  extminutes ${line:8}
                  if [ ${line:8} = '00:00:00' ] || [ $minutes -ge $statintv ]
                  then
                    # cut 3 very first utf-8 bytes and upload the stats
                    tail --bytes=+4 ./*.stat | perl r.pl 'stat' 'stat' | ./handle.sh $cmdl
                  fi
                fi
                echo -ne \\0357\\0273\\0277 > stats_done.log
              fi
            else
              if [ "${line:3:1}" = 's' ]
              then
                case ${line:4:1} in
                '2') sqlserver=$sql2;;
                '3') sqlserver=$sql;;
                *)   sqlserver='';;
                esac
                outcommand=${line:6:4}
                case $outcommand in
                'call')
                   {
#                    echo "set @@max_heap_table_size=134217728;"
#                    echo "set @@max_heap_table_size=268435456;"
                    echo "set @@max_heap_table_size=536870912;"
                    echo "CALL ${line:11}();"
                   } | $sqlserver 2>&1 | ./handle.sh $cmdl
                   ;;
                'take')
                   outtable=${line:11}
                   tosqlserver=$sqlserver
                   ;;
                'give')
                   echo "${line:11}" | $sqlserver 2>&1 | ./import.sh $outtable | $tosqlserver 2>&1 | ./handle.sh $cmdl &
                   ;;
                'prlc')
                   # call but as a parallel thread
                   {
                     echo "CALL ${line:11}();"
                   } | $sqlserver 2>&1 | ./handle.sh $cmdl &
                   ;;
                'init')
                   # handle dynamical request from sql for subscripts to
                   # be loaded to different servers
                   {
                     cat "${line:11}"
                   } | $sqlserver 2>&1 | ./handle.sh $cmdl
                   ;;
                *) ;;
                esac
                state=3 # communicate between servers
              else
                if [ "${line:3:2}" = '7z' ]
                then
                  while [ ! -f stats_done.log ]
                  do
                    sleep 2
                  done
                  # pack templates management info for delivery to AWB host

                  rm -f today.7z
                  7z a today.7z ./*.txt >7z.log 2>&1
                  rm -f ./*.txt

                  rm -f info.7z
                  7z a info.7z ./*.info >>7z.log 2>&1
                  rm -f ./*.info

                  7z a stat.7z ./*.stat >>7z.log 2>&1

                  todos 7z.log
                else
                  echo command: $line, not recognized >> debug.log
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  else
    case $state in           # Can't connect to MySQL server on '$dbhost' (111)'
    0) if [ "${line:0:20}" = 'ERROR 2003 (HY000): ' ] || [ "${line:0:20}" = 'ERROR 2013 (HY000): ' ] || [ "${line:0:20}" = 'ERROR 1130 (00000): ' ]
       then
         echo $dbhost is unavailable, now nothing will be applied
       else
         if [ "${line:0:20}" = 'ERROR 1049 (42000): ' ]
         then
           echo user database is not exist for some reason, need to be examined\; nothing will be applied
         else
           if [ "$line" != '' ]
           then
             echo -ne $line\\r\\n >> debug.log
           fi
         fi
       fi
       do_templates=0
       do_stat=0
       echo "$do_stat" > no_stat.log
       echo "$do_templates" > no_templates.log
       ;;
    1) echo -ne $line\\r\\n >> $out
       ;;
    2) echo -ne $line\\r\\n >> $out
       collection[${#collection[*]}]=$line
       ;;
    *) echo state: $state, $line >> debug.log
       ;;
    esac
  fi
}

while read -r line
  do handle "$line"
done
