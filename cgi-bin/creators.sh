#!/bin/bash

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
   
  <link rel="stylesheet" type="text/css" href="../main.css" media="all" /><style type="text/css">
  
  </style>
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="../wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"
echo -ne "<h1>"
if [ "$interface" = 'ru' ]
then
  echo -ne "<a href=\"./creators.sh?interface=en&user=$user&registered=$registered&shift=$shift\">[[en:]]</a> [[ru:]]"
else
  echo -ne "[[en:]] <a href=\"./creators.sh?interface=ru&user=$user&registered=$registered&shift=$shift\">[[ru:]]</a>"
fi
echo "</h1>"
echo -ne "<b><a href=\"../index"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">1) $motivation</a></b><br />"
echo "<br />"
echo "<b>2) <a href=\"http://ru.wikipedia.org/w/index.php?title=$isourl\">$isolatedarticles</a></b><br />"
echo "<ul>"
echo "<li><b><a href=\"./category.sh?interface=$interface\">$bycategory</a></b></li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface\">$allsuggestions</a></li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=disambigcat\">$resolvedisambigs</a></li>"
echo "<li>$justlink</li>"
echo "<ul>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=interlinkcat\">$parttranslate</a></li>"
echo "<li><a href=\"./suggest.sh?interface=$interface&listby=translatecat\">$translatenlink</a></li>"
echo "</ul>"
echo "</ul>"
echo "</ul>"
echo -ne "<li><b><a href=\"../lists"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">$wholelist</a></b></li>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/bytypes\">$byclastertype</a></b></li>"
echo "<ul><li><a href=\"http://ru.wikipedia.org/w/index.php?title=$orphurl\">$orphanes</a></li></ul>"
if [ "$user" = '' ]
then
  echo "<li><b><font color=red>$bycreator</font></b></li>"
else
  echo "<li><b><a href=\"./creators.sh?interface=$interface\">$bycreator</a></b></li>"
  echo "<ul>"
  echo "<li><font color=red>${usrns}:$user</font></li>"
  echo "</ul>"
fi
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/cltgdata\">$graphdata</a></b></li>"
echo "</ul>"
echo "<br />"
echo "<b>3) <a href=\"http://ru.wikipedia.org/w/index.php?title=$deadendurl\">$deadend</a></b><br />"
echo "<br />"
echo "<b>4) <a href=\"./disambig.sh?interface=$interface\">$disambig</a></b><br />"
echo "<br />"
echo "<b>5) <a href=\"./category14.sh?interface=$interface\">$cattreecon</a></b><br />"
echo "<br />"
echo "<b>6) $contactme</b><br />"
echo "<ul>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User:Mashiah_Davidson\">$mywikipage</a></li>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User:%D0%93%D0%BE%D0%BB%D0%B5%D0%BC\">$botwikipage</a></li>"
echo "<li><a href=\"http://ru.wikipedia.org/wiki/User Talk:%D0%93%D0%BE%D0%BB%D0%B5%D0%BC\">$commondisc</a></li>"
echo "<li>mashiah $attext <a href="irc://irc.freenode.net/$ircchan">#$ircchan</a></li>"
echo "</ul>"
echo "<p align=justify>$srclocation <a href="http://fisheye.ts.wikimedia.org/browse/mashiah">toolserver fisheye</a>.</p>"

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

how_actual creatorizer

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
  } | $sql 2>&1 | { 
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
                count\(*\) as cnt  \
                FROM creators0     \
                GROUP BY user_text \
                ORDER BY cnt DESC  \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
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

 <body>
</html>
EOM
