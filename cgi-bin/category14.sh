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
  <title>Categorytree connectivity for ruwiki</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
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


<h2>categorytree connectivity (ruwiki)</h2>
The categorytree structure collection is run manually and updated daily or close to.<br>
So, use once a day before a notification.<br><br>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=sql-s3 -A --user=${usr} --password=${pwd} --database=u_${usr}"

parse_query networkpath

if [ "$networkpath" != '' ]
then
  echo "<h4>$networkpath</h4>"

  if [ "$networkpath" = '_1' ]
  then
    echo "<font color=red>"
    echo "The list below normally must contain just one category named <font color=green>Всё</font>.<br />"
    echo "Other entries are considered as uncotegorized categories.<br />"
    echo "</font>"
  fi

  if [[ "$networkpath" =~ '^.*\_([1-9][1-90]+|[2-9])$' ]]
  then
    echo "<font color=red>"
    echo "The list below shows categories forming clusters of size ${BASH_REMATCH[1]}.<br />"
    echo "Normally it must be empty (and unexistent), there must be no clusters of size above one in the categorytree.<br />"
    echo "</font>"
  fi

  echo "<ol>"
  echo SELECT title                           \
              FROM ruwiki14                   \
                   WHERE cat=\'$networkpath\' \
                   ORDER BY title ASC\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\<a href="http\:\/\/ru.wikipedia.org\/wiki\/Категория:\1" target=\"_blank\"\>\1\<\/a\>\<\/li\>/' -e 's/_/ /g'
  echo "</ol>"
  echo "end of the list"
else
  echo "Each row in the table represents a layer in the categorytree."
  echo "Normally layers are formed by categorization of categories and must have no cycles."
  echo "All the layers having a number higher than 1 at the end of the layer name are wrong and represent cycles."
  echo "Also it is important to keep the top layer category _1 having the single top member.<br />"
fi

echo "<center><table border=0><tr><th>Categorytree structure</th></tr><tr><td><small>"
echo SELECT coolcat,            \
            count\(cat\) as cnt \
            FROM orcat14,       \
                 ruwiki14       \
            WHERE coolcat=cat   \
            GROUP BY cat        \
            ORDER BY coolcat ASC\; | $sql -N | sed -e 's/^\(.*\)\s\([1-9][0-9]*\)$/\<a href="\/\~mashiah\/cgi-bin\/category14.sh\?networkpath=\1"\>\1\<\/a\>:\&nbsp\;\2\<br \/\>/'
echo "</small></td></tr></table></center>"

if [ "$networkpath" = '' ]
then
  echo "<h4>redirects</h4>"
  echo "<font color=red>"
  echo "Categories namespace is not designed for redirects.<br />"
  echo "Categorization through a redirect does not construct proper category lists.<br />"
  echo "</font>"
  
  echo "<ol>"
  echo SELECT r_title  \
              FROM r14 \
              ORDER BY r_title ASC\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\<a href="http\:\/\/ru.wikipedia.org\/w\/index.php\?title=Категория:\1\&redirect=no" target=\"_blank\"\>\1\<\/a\>\<\/li\>/' -e 's/_/ /g'
  echo "</ol>"
  echo "end of the list"

  echo "<h4>redirects with more than one outgoing link</h4>"
  echo "<font color=red>"
  echo "This list contains maybe a bit more complex for resolving type of redirects.<br />"
  echo "It contains redirects in category namespace with articles included into this redirec as in a category, or even redirects with superflous text and links, which are normally invisible.<br />"
  echo "Redirects to main namespace with articles included are probably not redirects, but regular categories.<br />"
  echo "Other redirects linking categories need to be emptied before redirect deletion.<br />"
  echo "</font>"
  
  echo "<ol>"
  echo SELECT wr_title  \
              FROM wr14 \
              ORDER BY wr_title ASC\; | $sql -N | sed -e 's/^\(.*\)$/\<li\>\<a href="http\:\/\/ru.wikipedia.org\/w\/index.php\?title=Категория:\1\&redirect=no" target=\"_blank\"\>\1\<\/a\>\<\/li\>/' -e 's/_/ /g'
  echo "</ol>"
  echo "end of the list"
fi


cat << EOM

<h2><a href="./category.sh">isolated articles for a particular category (ruwiki)</a></h2>
<h2><a href="./suggest.sh">suggest a link for isolated articles (ruwiki)</a></h2>

 <body>
</html>
EOM
