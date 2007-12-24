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
  <title>Suggest a link for isolated articles</title><link rel="stylesheet" type="text/css" href="/~mashiah/main.css" media="all" /><style type="text/css">
  
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


<h2>suggest a link for isolated articles (ruwiki)</h2>
EOM

usr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
pwd=$( cat ~/.my.cnf | grep 'password ' | sed 's/^password = \"\([^\"]*\)\"$/\1/' )
sql="mysql --host=sql-s3 -A --user=${usr} --password=${pwd} --database=u_${usr}"

parse_query title
parse_query id

if [ "$title" = '' ]
then
  echo "<h4>isolated articles linked from disambiguations linked from articles</h4>"
  echo "Isolated articles below are linked from disambiguation pages, which are also linked from regular articles.<br />"
  echo "This is a chance for both, making isolated articles linked, or making disambiguation pages not linked from articles directly.<br />"

  echo "<ol>"
  echo SELECT DISTINCT page_title, \
              a2i_to               \
              FROM a2i,            \
                   ruwiki_p.page   \
              WHERE page_id=a2i_to \
              ORDER BY page_title ASC\; | $sql -N | sed -e 's/^\(.*\)\s\([1-9][1-90]*\)$/\<li\>\<a href="\/\~mashiah\/cgi-bin\/suggest.sh\?id=\2\&title=\1"\>\1\<\/a\>\<\/li\>/' -e 's/_/ /g'
  echo "</ol>"
  echo "end of the list"
else
  echo "<h4><a href=\"http://ru.wikipedia.org/wiki/$title\">$title</a></h4>"
  echo "Based on disambiguation links analysis, this isolated article may become linked from the following articles:<br />"

  echo "<font color=red>"
  echo "Note that chronological articles and collaborative list do not form valid links.<br />"
  echo "They can be considered for links pointing disambiguation pages cleanup.<br />"
  echo "</font>"

  echo "<ul>"
  echo CALL dsuggest\(\'$id\'\)\; | $sql -N | sed -e 's/^\(\:\:\:\:\|\:\:\)\(.*\)\(\!\!\!\|\:\:\:\)$/\<li\>\1\<a href="http\:\/\/ru.wikipedia.org\/wiki\/\2" target=\"_blank\"\>\2\<\/a\>\3\<\/li\>/' -e 's/\!\!\![\<]\/li[\>]$/\<\/li\>/' -e 's/::::/\&nbsp;\&nbsp;\&nbsp;/'  -e 's/:::/\<\/b\>/'  -e 's/::/\<b\>/' -e 's/_/ /g'
  echo "</ul>"
fi

cat << EOM

<h2><a href="./category.sh">isolated articles for a particular category (ruwiki)</a></h2>

<h2><a href="./category14.sh">categorytree connectivity (ruwiki)</a></h2>

 <body>
</html>
EOM
