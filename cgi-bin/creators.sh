#!/bin/bash

script="creators"
source ./common

handle_userlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local utxt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\1/g' )
    local uid=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\2/g' )
    local amnt=$( echo $line | sed -e 's/^\(.*\+\) \([0-9]\+\) \([0-9]\+\)/\3/g' )
    echo "<li><a href='./creators.sh?$stdurl&listby=creator&user=$utxt&registered=$uid'>$utxt</a>: $amnt</li>"
  fi
}

how_actual creatorizer

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

if [ "$user" = '' ] || [ "$registered" = '' ]
then
  echo "$whatisit<br><br>"
fi
echo $example
echo "<FORM action=\"./creators.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
echo "<INPUT type=hidden name=\"listby\" value=\"$listby\">"
echo "<P><font color=red>$unamereq: <INPUT name=user type=\"text\"> $activateform</font></P>"
echo "</FORM>"

UPPERFIRST=`echo "$user" | cut -c 1  |tr '[a-z]' '[A-Z]'`
user=$( echo "$user" | sed 's/./'$UPPERFIRST'/'1)

if [ "$user" != '' ]
then
  usersql=${user//\"/\"\'\"\'\"}
  echo -ne "<br />$list1expl "
  if [ "$registered" = '0' ]
  then
    echo "<a href='http://$language.wikipedia.org/wiki/Special:Contributions/$user' target=\"_blank\">$user</a>"
  else
    echo "<a href=\"http://$language.wikipedia.org/w/index.php?title=User:${user_url}\" target=\"_blank\">$user</a>"
  fi

  echo "<table class=\"sortable infotable\">"
  echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
  {
    echo SELECT cat,                               \
                title                              \
                FROM creators0,                    \
                     ruwiki0                       \
                WHERE user_text=\"${usersql}\" and \
                      iid=id                       \
                ORDER BY title ASC\;
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
  if [ "$registered" = '0' ]
  then
    echo "<br />$anonymous_s<br />"
    echo "<table class=\"sortable infotable\">"
    echo "<tr><th>&#8470;</th><th>$article_title_tr</th><th>$iso_type_tr</th></tr>"
    {
      echo SELECT cat,             \
                  title            \
                  FROM creators0,  \
                       ruwiki0     \
                  WHERE user=0 and \
                        iid=id     \
                  ORDER BY title ASC\;
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
    if [ "$registered" = '' ]
    then
      echo "<h4>$list2name</h4>"

      shifter
      echo "<ol start=$((shift+1))>"
      {
        echo SELECT user_text,         \
                    sign\(user\),      \
                    count\(\*\) as cnt \
                    FROM creators0     \
                    GROUP BY user_text \
                    ORDER BY cnt DESC  \
                    LIMIT $((shift)),100\;
      } | $( sql ${dbserver} u_${usr}_golem_s${dbserver}_${language} ) 2>&1 | { 
                        while read -r line
                          do handle_userlist "$line"
                        done
                      }
      echo "</ol>"
      shifter
#
#    this could be for the list of all isolated articles
#    created by registered users
#
#    else
    fi
  fi
fi

#
# Standard page footer
#
the_footer
