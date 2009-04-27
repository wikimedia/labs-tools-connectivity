#!/bin/bash

language="ru"
script="creators"
source ./common

parse_query user
parse_query interface
parse_query registered
parse_query shift
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./creators.$interface
source ./common2

handle_isolates ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    echo "<li><a href=\"http://ru.wikipedia.org/w/index.php?title=$line\" target=\"_blank\">$line</a> <small><a href=\"./suggest.sh?interface=$interface&title=$line\"><font color=green>[[$suggest]]</font></a></small></li>"
  fi
}

handle_userlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local utxt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\1/g' )
    local uid=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\2/g' )
    local amnt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\3/g' )
    echo "<li><a href='./creators.sh?interface=$interface&user=$utxt&registered=$uid'>$utxt</a>: $amnt</li>"
  fi
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
EOM

echo "<title>$pagetitle</title>"

cat << EOM
   
  <link rel="stylesheet" type="text/css" href="../main.css" media="all" />
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="../wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM
how_actual creatorizer

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"

#
# The menu
#
the_menu

echo "</td><td width=75%>"

echo "<h1>$thish1</h1>"

echo "$whatisit<br><br>"
echo $example
echo "<FORM action=\"./creators.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<P><font color=red>$unamereq: <INPUT name=user type=\"text\"> $unamedo</font></P>"
echo "</FORM>"

shiftnext=$((shift+100))
shiftprev=$((shift-100))

UPPERFIRST=`echo "$user" | cut -c 1  |tr '[a-z]' '[A-Z]'`
user=$( echo "$user" | sed 's/./'$UPPERFIRST'/'1)
userurl=${user//\"/\%22}
usersql=${user//\"/\"\'\"\'\"}

if [ "$user" != '' ]
then
  echo -ne "<br />$list1expl "
  if [ "$registered" = '0' ]
  then
    echo "<a href='http://ru.wikipedia.org/wiki/Special:Contributions/$user' target=\"_blank\">$user</a>"
  else
    echo "<a href=\"http://ru.wikipedia.org/w/index.php?title=User:$userurl\" target=\"_blank\">$user</a>"
  fi
  echo "<ol>"
  {
    echo SELECT title                          \
                FROM creators0                 \
                WHERE user_text=\"${usersql}\" \
                ORDER BY title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_isolates "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
else
  echo "<h4>$list2name</h4>"

  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./creators.sh?shift=$shiftprev&interface=$interface\">$previous 100</a> "
  fi
  echo "<a href=\"./creators.sh?shift=$shiftnext&interface=$interface\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT user_text,         \
                user,              \
                count\(\*\) as cnt \
                FROM creators0     \
                GROUP BY user_text \
                ORDER BY cnt DESC  \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_userlist "$line"
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./creators.sh?shift=$shiftprev&interface=$interface\">$previous 100</a> "
  fi
  echo "<a href=\"./creators.sh?shift=$shiftnext&interface=$interface\">$next 100</a>"
fi

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
