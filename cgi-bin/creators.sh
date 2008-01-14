#!/bin/bash

# Mashiah Davidson: # Thanks a lot to Chris F.A. Johnson for my time saved.
# This function copied as is from 
# http://www.unixreview.com/documents/s=10116/ur0701i/parse-query.sh.txt
parse_query() #@ USAGE: parse_query var ...                                                                 
{
  local var val
  local IFS='&'
  vars="&$*&"
  [ "$REQUEST_METHOD" = "POST" ] && read QUERY_STRING
  set -f
  for item in $QUERY_STRING
  do
    var=${item%%=*}
    val=${item#*=}
    val=${val//+/ }
    case $vars in
      *"&$var&"* )
        case $val in
          *%[0-9a-fA-F][0-9a-fA-F]*)
            val=$( printf "%b" "${val//\%/\\x}." )
            val=${val%.}
        esac
        eval "$var=\$val"
        ;;
    esac
  done
  set +f
}

handle_isolates ()
{
  local line=$1
  line=${line//_/ }
  echo \<li\>\<a href=\"http://ru.wikipedia.org/w/index.php?title=$line\" target=\"_blank\"\>$line\<\/a\> \<small\>\<a href=\"/~mashiah/cgi-bin/suggest.sh?title=$line\"\>[[suggest links]]\<\/a\>\<\/small\>\<\/li\>
}

handle_userlist ()
{
  local line=$1
  local utxt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\1/g' )
  local uid=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\2/g' )
  local amnt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\3/g' )
  echo "<li><a href='/~mashiah/cgi-bin/creators.sh?user=$utxt&registered=$uid'>$utxt</a>: $amnt</li>"
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <title>Isolated articles creators for ruwiki</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
  </style>
 </head>
 <body>
  <a href="/"><img id="poweredbyicon" src="/~mashiah/wikimedia-toolserver-button.png" alt="Powered by
    Wikimedia-Toolserver" /></a>
  <h1><a href="/~mashiah">Mashiah's Projects</a></h1>

<h2>contact</h2>
<ul>
<li>see <a href="http://ru.wikipedia.org/wiki/User:Mashiah_Davidson">my russian userpage</a>, <a href="http://ru.wikipedia.org/wiki/User:Голем">my bot's page</a> and <a href="http://ru.wikipedia.org/wiki/User Talk:Голем">our shared discussion</a></li>
<li>look for me (nick: mashiah) in <a href="irc://irc.freenode.net/wikimedia-toolserver">#wikimedia-toolserver</a> on freenode</li>
</ul>

<h2>isolated articles creators (ruwiki)</h2>
This page contains the lists of users who created isolated articles, it is
ordered by the amount of isolated articles created.<br>
Example: Maximaximax
<FORM action=""/~mashiah/cgi-bin/creators.sh"" method="post">
<P><font color=red>Enter a user name: <INPUT name=user type="text"> and hit enter</font></P>
</FORM>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
sql="mysql --defaults-file=/home/mashiah/.my.cnf --host=sql-s3 -A --database=u_${usr} -N"

parse_query user
parse_query registered
parse_query shift

shiftnext=$((shift+100))
shiftprev=$((shift-100))

UPPERFIRST=`echo "$user" | cut -c 1  |tr '[a-z]' '[A-Z]'`
user=$( echo "$user" | sed 's/./'$UPPERFIRST'/'1)
userurl=${user//\"/\%22}
usersql=${user//\"/\"\'\"\'\"}

if [ "$user" != '' ]
then
  if [ "$registered" = '0' ]
  then
    echo "<h4><a href='http://ru.wikipedia.org/wiki/Special:Contributions/$user' target=\"_blank\">$user</a></h4>"
  else
    echo "<h4><a href=\"http://ru.wikipedia.org/w/index.php?title=User:$userurl\" target=\"_blank\">$user</a></h4>"
  fi
  echo "this is the list of isolated articles created by $user"
  echo "<ol>"
  {
    echo SELECT title                       \
                FROM creators               \
                WHERE user_text=\"${usersql}\" \
                ORDER BY title ASC;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_isolates "$line"
                    done
                  }
  echo "</ol>"
else
  echo "<h4>top 100 users on amount of isolated articles created</h4>"

  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"/~mashiah/cgi-bin/creators.sh?shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/creators.sh?shift=$shiftnext\">next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT user_text,         \
                user,              \
                count\(*\) as cnt  \
                FROM creators      \
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
    echo "<a href=\"/~mashiah/cgi-bin/creators.sh?shift=$shiftprev\">previous 100</a> "
  fi
  echo "<a href=\"/~mashiah/cgi-bin/creators.sh?shift=$shiftnext\">next 100</a>"
fi

cat << EOM

<h2><a href="./category.sh">isolated articles for a particular category (ruwiki)</a></h2>
<h2><a href="./category14.sh">categorytree connectivity (ruwiki)</a></h2>
<h2><a href="./suggest.sh">suggest a link for isolated articles (ruwiki)</a></h2>
 <body>
</html>
EOM
