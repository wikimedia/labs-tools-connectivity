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

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
  <title>Isolated articles in $1 for ruwiki</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
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
Example: Материалы БСЭ
<!-- ISINDEX prompt="Category name:" action="/~mashiah/cgi-bin/category.sh" -->
<FORM action=""/~mashiah/cgi-bin/category.sh"" method="post">
<P>Category name: <INPUT name=category type="text"></P>
</FORM>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=sql-s3 -A --user=${usr} --password=${pwd} --database=u_${usr}"

parse_query category

if [ "$category" != '' ]
then
  echo "<h4>$category</h4>"
  convertedcat=$( echo $category | sed -e 's/ /_/g' )

  echo "<ol>"
  echo SELECT title                                \
              FROM ruwiki_p.categorylinks,         \
                   ruwiki0                         \
                   WHERE id=cl_from and            \
                         cl_to=\'${convertedcat}\' \
                   ORDER BY title ASC\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\<a href="http\:\/\/ru.wikipedia.org\/wiki\/\1" target=\"_blank\"\>\1\<\/a\>\<\/li\>/' -e 's/_/ /g'
  echo "</ol>"
  echo "end of the list"
else
  echo "<h4>top 100 categories on isolated pages count</h4>"

  echo "<ul>"
  echo SELECT CONCAT\( \'\<a href=\"\/\~mashiah\/cgi-bin\/category.sh\?category=\', cl_to, \'\" target=\"blank\"\>\', cl_to, \'\<\/a\>\' \), \
              count\( \*\ \) as cnt,                                                                                                         \
              CONCAT\( \'\(\',100\*count\(\*\)/cv_count,\'\%\)\' \)                                                                          \
              FROM ruwiki_p.categorylinks,                                                                                                   \
                   ruwiki0,                                                                                                                  \
                   catvolume                                                                                                                 \
                   WHERE id=cl_from and                                                                                                      \
                         cv_title=cl_to                                                                                                      \
                   GROUP BY cl_to                                                                                                            \
                   ORDER BY cnt DESC                                                                                                         \
                   LIMIT 100\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\1\<\/li\>/' -e 's/_/ /g'
  echo "</ul>"
  echo "end of the list"
  echo "<h4>top 100 categories on isolated pages ratio</h4>"

  echo "<ul>"
  echo SELECT CONCAT\( \'\<a href=\"\/\~mashiah\/cgi-bin\/category.sh\?category=\', cl_to, \'\" target=\"blank\"\>\', cl_to, \'\<\/a\>\' \), \
              count\(\*\) as cnt,                                                                                                            \
              CONCAT\(\'\(\',100\*count\(\*\)/cv_count,\'\%\)\'\)                                                                            \
              FROM ruwiki_p.categorylinks,                                                                                                   \
                   ruwiki0,                                                                                                                  \
                   catvolume                                                                                                                 \
                   WHERE id=cl_from and                                                                                                      \
                         cv_title=cl_to                                                                                                      \
                   GROUP BY cl_to                                                                                                            \
                   ORDER BY 100\*count\(\*\)/cv_count DESC, cnt DESC                                                                         \
                   LIMIT 100\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\1\<\/li\>/' -e 's/_/ /g'
  echo "</ul>"
  echo "end of the list"
fi

cat << EOM

<h2><a href="./category14.sh">categorytree connectivity (ruwiki)</a></h2>
<h2><a href="./suggest.sh">suggest a link for isolated articles (ruwiki)</a></h2>
 <body>
</html>
EOM
