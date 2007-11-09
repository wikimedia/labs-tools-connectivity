 # 
 # Handler for 
 # '''[[:ru:User:Mashiah_Davidson/toolserver/isolated.sql|isolated.sql]]'''.
 # 
 # Works on the Toolserver and outputs the processing results into a set
 # of files being switched by some API calls from '''isolated.sql'''.
 #
 # <pre>

#!/bin/bash

do_apply=0
if [ "$1" = "apply" ]
then
  do_apply=1
fi

dbhost="sql-s3"
myusr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
mypwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=$dbhost -A --user=${myusr} --password=${mypwd} --database=u_${myusr} -n"

ruusr=$( cat ~/.ru.cnf | grep 'user ' | sed 's/^user = \"\([^\"]*\)\"$/\1/' )
rupwd=$( cat ~/.ru.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )

rm -f ./*.info ./*.txt ./*.stat debug.log

out='';
handle ()
{
  local line=$1

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
  $sql -N $debugmode <isolated.sql 2>&1 | { state=0; while read -r line ; do handle "$line" ; done }

  rm -f today.7z
  7z a today.7z ./*.txt >7z.log 2>&1
  rm -f ./*.txt

  rm -f info.7z
  7z a info.7z ./*.info >>7z.log 2>&1
  rm -f ./*.info

  7z a stat.7z ./*.stat >>7z.log 2>&1
  if [ "$do_apply" = "1" ]
  then
    tail --bytes=+4 ./*.stat | perl r.pl 'stat' "$ruusr" "$rupwd" 'stat'
  fi

  todos 7z.log
}

# </pre>