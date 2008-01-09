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

handle_category ()
{
  local line=$1
  line=${line//_/ }
  echo \<li\>\<a href=\"http://ru.wikipedia.org/w/index.php?title=$line\" target=\"_blank\"\>$line\<\/a\> \<small\>\<a href=\"/~mashiah/cgi-bin/suggest.sh?title=$line\"\>[[suggest links]]\<\/a\>\<\/small\>\<\/li\>
}

handle_catlist ()
{
  local line=$1
  local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\1/g' )
  local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\2/g' )
  local percent=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\3/g' )
  name=${name//_/ }
  echo \<li\>\<a href=\"/~mashiah/cgi-bin/category.sh?category=$name\"\>$name\<\/a\>: $volume \($percent\%\)\<\/li\>
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <title>Isolated articles for ruwiki</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
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


<h2>isolated articles for a particular category (ruwiki)</h2>
The list of isolated articles is collected manually and updated on a daily
basis or close to.<br>
So, use once a day for each particular category name.<br><br>
Example: Писатели России
<FORM action=""/~mashiah/cgi-bin/category.sh"" method="post">
<P><font color=red>Enter your category name: <INPUT name=category type="text"> and hit enter</font></P>
</FORM>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=sql-s3 -A --user=${usr} --password=${pwd} --database=u_${usr} -N"

parse_query category

categoryurl=${category//\"/\%22}
categorysql=${category//\"/\"\'\"\'\"}

if [ "$category" != '' ]
then
  echo "<h4>$category</h4>"
  echo "this is a list of all isolated articles for the category,<br />"
  echo "see also:"
  echo "<ul>"
  echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?category=$categoryurl&suggest=disambig\">list of isolated articles <b>linked from linked disambiguation pages</b></a></li>"
  echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?category=$categoryurl&suggest=interlink\">list of isolated articles <b>with linking suggestions</b></a></li>"
  echo "<li><a href=\"/~mashiah/cgi-bin/suggest.sh?category=$categoryurl&suggest=translate\">list of isolated articles <b>with translation suggestions</b></a></li>"
  echo "</ul>"
  convertedcat=$( echo $categorysql | sed -e 's/ /_/g' )

  echo "<ol>"
  {
    echo SELECT title                                \
                FROM ruwiki_p.categorylinks,         \
                     ruwiki0                         \
                     WHERE id=cl_from and            \
                           cl_to=\"${convertedcat}\" \
                     ORDER BY title ASC\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo "end of the list"
else
  echo "<h4>top 100 categories on isolated pages count</h4>"

  echo "<ul>"
  {
    echo SELECT cv_title,                 \
                cv_isocount,              \
                100\*cv_isocount/cv_count \
                FROM catvolume            \
                ORDER BY cv_isocount DESC \
                LIMIT 100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ul>"
  echo "end of the list"

  echo "<h4>top 100 categories on isolated pages ratio</h4>"

  echo "<ul>"
  {
    echo SELECT cv_title,                            \
                cv_isocount,                         \
                100\*cv_isocount/cv_count as pcnt    \
                FROM catvolume                       \
                ORDER BY pcnt DESC, cv_isocount DESC \
                LIMIT 100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ul>"
  echo "end of the list"
fi

cat << EOM

<h2><a href="./category14.sh">categorytree connectivity (ruwiki)</a></h2>
<h2><a href="./suggest.sh">suggest a link for isolated articles (ruwiki)</a></h2>
<h2><a href="./creators.sh">isolated articles creators (ruwiki)</a></h2>
 <body>
</html>
EOM
