#!/bin/bash

script="category"
source ./common

how_actual isolatedbycategory

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"
echo $example
echo "<FORM action=\"./category.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<INPUT type=hidden name=\"listby\" value=\"$listby\">"
if [ "$shift_url" != '' ]
then
  echo "<INPUT type=hidden name=\"shift\" value=\"$shift\">"
fi
echo "<P><font color=red>$catnamereq: <INPUT name=category type=\"text\"> $activateform</font></P>"
echo "</FORM>"

#
# this allows the row passing through all the quatermarks and finaly be
# delivered in sql as \"
#
categorysql=${category//\"/\"\'\\\\\"\'\"}

if [ "$category" != '' ]
then
  echo "<br />$submenudesc"
  convertedcat=${categorysql// /_}

  echo "<table class=\"sortable infotable\">"
  echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
  {
    echo CALL isolated_for_category\(\"${convertedcat}\"\, \'${language}\'\)\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    count=0
                    while read -r line
                      do handle_isolates_as_table $((count+1)) "$line"
                      count=$((count+1))
                    done
                  }
  echo "</table>"
  echo '<script type="text/javascript" src="../sortable.js"></script>'
else
  echo "<h3>$top1name</h3>"

  shifter
  echo "<ol start=$((shift+1))>"
  {
    echo CALL ordered_cat_list\( \"isocatvolume0\", $((shift)) \)\;
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ol>"
  shifter

  echo "<h3>$top2name</h3>"

  shifter
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
  } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line"
                    done
                  }
  echo "</ol>"
  shifter
fi

#
# Standard page footer
#
the_footer
