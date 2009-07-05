#!/bin/bash

script="category"
source ./common

parse_query category
parse_query shift

source ./common.$interface
source ./$script.$interface
source ./common2

handle_catlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\1/g' )
    local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\2/g' )
    local percent=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\) \([^ ]\+\)/\3/g' )
    name=${name//_/ }
    local cname=${name//\?/\%3F}
    cname=${cname//\&/\%26}
    cname=${cname//\"/\%22}
    echo "<li><a href=\"./category.sh?language=$language&interface=$interface&category=$cname\">$name</a>: $volume ($percent%)</li>"
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
how_actual isolatedbycategory

#
# Switching between interface languages at the top right
#
if_lang

#
# The page header at the center
#
the_page_header


echo "<table><tr><td width=25% border=10>"

#
# The menu
#
the_menu

echo "</td><td width=75%>"

echo "<h1>$thish1</h1>"
echo "$howoften<br><br>"
echo $example
echo "<FORM action=\"./category.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
echo "<P><font color=red>$catnamereq: <INPUT name=category type=\"text\"> $catnamedo</font></P>"
echo "</FORM>"

categoryurl=${category//\"/\%22}
#
# this allows the row passing through all the quatermarks and finaly be
# delivered in sql as \"
#
categorysql=${category//\"/\"\'\\\\\"\'\"}

if [ "$category" != '' ]
then
  echo "<br />$submenudesc <a href=\"http://$language.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"
  convertedcat=$( echo $categorysql | sed -e 's/ /_/g' )
  echo "<ol>"
  {
    echo CALL isolated_for_category\(\"${convertedcat}\"\, \'${language}\'\)\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_isolates "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
else
  echo "<h4>$top1name</h4>"

  echo "<ol start=$((shift+1))>"
  {
    echo SELECT title,                                \
                isocatvolume0.cnt,                    \
                100\*isocatvolume0.cnt/catvolume0.cnt \
                FROM catvolume0,                      \
                     isocatvolume0,                   \
                     categories                       \
                WHERE catvolume0.cat=id and           \
                      isocatvolume0.cat=id            \
                ORDER BY isocatvolume0.cnt DESC       \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h4>$top2name</h4>"

  echo "<ol start=$((shift+1))>"
  {
    echo SELECT title,                                        \
                isocatvolume0.cnt,                            \
                100\*isocatvolume0.cnt/catvolume0.cnt as pcnt \
                FROM catvolume0,                              \
                     isocatvolume0,                           \
                     categories                               \
                WHERE catvolume0.cat=id and                   \
                      isocatvolume0.cat=id                    \
                ORDER BY pcnt DESC, isocatvolume0.cnt DESC    \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
fi

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
