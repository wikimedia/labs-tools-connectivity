#!/bin/bash

language="ru"
script="suggest"
source ./common

parse_query title
parse_query interface
parse_query listby
parse_query shift
parse_query category
parse_query suggest
if [ "$interface" != 'ru' ]
then
  interface='en'
fi

source ./common.$interface
source ./suggest.$interface
source ./common2

handle_isotype ()
{
  local line=$1

  if [ "$line" != '' ]
  then
    isotype="$line"
  fi
}

handle_catlist ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local suggest=$2
    local name=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\1/g' )
    local volume=$( echo $line | sed -e 's/^\([^ ]\+\) \([^ ]\+\)/\2/g' )
    name=${name//_/ }
    local cname=${name//\?/\%3F}
    cname=${cname//\&/\%26}
    cname=${cname//\"/\%22}
    echo "<li><a href=\"./suggest.sh?interface=$interface&category=$name&suggest=$suggest\">$name</a>: $volume</li>"
  fi
}

handle_dsmbg ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      test=${test//_/ }
      local ctest=${test//\?/\%3F}
      ctest=${ctest//\&/\%26}
      ctest=${ctest//\"/\%22}
      echo "</ol><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$ctest\" target=\"_blank\">$test</a></b></li><ol>"
    else
      article=${article//_/ }
      local carticle=${article//\?/\%3F}
      carticle=${carticle//\&/\%26}
      carticle=${carticle//\"/\%22}
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://ru.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

handle_lnk ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      echo "</ol><b><a href=\"http://$test.wikipedia.org\" target=\"_blank\">$test</a></b><ol>"
    else
      article=${article//_/ }
      local carticle=${article//\?/\%3F}
      carticle=${carticle//\&/\%26}
      carticle=${carticle//\"/\%22}
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://ru.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

handle_trns ()
{
  local line=$1

  if no_sql_error "$line"
  then
    local test=$( echo $line | sed -e 's/^\:\:\([^\:].*\)$/\1/' )
    local article=$( echo $line | sed -e 's/^\:\:\:\(.*\)$/\1/' )

    if [ "${test:0:2}" != '::' ]
    then
      lang=$test;
      echo "</ol><b><a href=\"http://${lang}.wikipedia.org\" target=\"_blank\">$lang</a></b><ol>"
    else
      article=${article//_/ }
      local carticle=${article//\?/\%3F}
      carticle=${carticle//\&/\%26}
      carticle=${carticle//\"/\%22}
      echo "<li>&nbsp;&nbsp;&nbsp;<a href=\"http://${lang}.wikipedia.org/w/index.php?title=$carticle\" target=\"_blank\">$article</a></li>"
    fi
  fi
}

handle_category ()
{
  local line=$1

  if no_sql_error "$line"
  then
    line=${line//_/ }
    local lineurl=${line//\?/\%3F}
    lineurl=${lineurl//\&/\%26}
    lineurl=${lineurl//\"/\%22}
    echo "<li><a href=\"./suggest.sh?interface=$interface&title=$lineurl\"\>$line</a></li>"
  fi
}

suggestions ()
{
  echo "<h3>$sggclause0</h3>"
  echo "$sggclause1<br />"
  echo "<font color=red><ul><li>$sggclause2 $sggclause3</li></ul></font>"

  convertedtitle=$( echo $titlesql | sed -e 's/ /_/g' )
  echo "<ol>"
  {
    echo CALL dsuggest\(\"$convertedtitle\"\, \'${language}\'\)\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_dsmbg "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h3>$sggclause4</h3>"
  echo "$sggclause5<br />"

  echo "<font color=red><ul><li>$sggclause2</li></ul></font>"

  echo "<ol>"
  {
    echo CALL interwiki_suggest\(\"$convertedtitle\"\)\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_lnk "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  echo "<h3>$sggclause6</h3>"
  echo "$sggclause7<br />"

  echo "<font color=red><ul><li>$sggclause2</li></ul></font>"

  echo "<ol>"
  {
    echo CALL interwiki_suggest_translate\(\"$convertedtitle\"\)\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    lang=''
                    while read -r line
                      do handle_trns "$line"
                    done
                  }
  echo "</ol>"
  echo $listend
}

echo Content-type: text/html
echo ""

cat << EOM
﻿<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
 <head>
EOM

echo "<title>$pagetitle</title>"

cat << EOM
  <link rel="stylesheet" type="text/css" href="../main.css" media="all" />
 </head>
 <body>
<a href="/"><img id="poweredbyicon" src="../wikimedia-toolserver-button.png" alt="Powered by Wikimedia-Toolserver" /></a>
EOM
case $listby in
'') 
  if [ "$title" = '' ]
  then
    case $suggest in
    'disambig')
      how_actual dsuggestor
      ;;
    'interlink')
      how_actual lsuggestor
      ;;
    'translate')
      how_actual tsuggestor
      ;;
    *)
      how_actual tsuggestor
      ;;
    esac
  else
    how_actual tsuggestor
  fi
  ;;
'disambig')
  how_actual dsuggestor
  ;;
'disambigcat')
  how_actual dsuggestor
  ;;
'interlink')
  how_actual lsuggestor
  ;;
'interlinkcat')
  how_actual lsuggestor
  ;;
'translate')
  how_actual tsuggestor
  ;;
'translatecat')
  how_actual tsuggestor
  ;;
*)
  ;;
esac

echo "<h1>$mainh1</h1>"
echo "<table><tr><td width=25% border=10>"

#
# The menu
#
the_menu

echo "</td><td width=75%>"

echo "<h1>$thish1</h1>"

echo "<FORM action=\"./suggest.sh\" method=\"get\">"
echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
echo "<P><font color=red>$ianamereq: <INPUT name=title type=\"text\"> $ianamedo</font></P>"
echo "</FORM>"

shiftnext=$((shift+100))
shiftprev=$((shift-100))

case $listby in
'')
  if [ "$title" = '' ]
  then
    if [ "$category" = '' ]
    then
      echo "<br />$clause1<br /><br />"
      echo "<font color=red>$clause2</font><br />"
      echo "<ul><li>$clause3</li><li>$clause4</li></ul>"
    else
      convertedcat=$( echo $category | sed -e 's/ /_/g' )

      case $suggest in
      'disambig')
        echo "<br />$submenu1desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"

        echo "<ol>"
        {
          echo CALL isolated_for_category_dsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
        } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo $listend
        ;;
      'interlink')
        echo "<br />$submenu2desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"

        echo "<ol>"
        {
          echo CALL isolated_for_category_ilsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
        } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo $listend
        ;;
      'translate')
        echo "<br />$submenu3desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"

        echo "<ol>"
        {
          echo CALL isolated_for_category_itsuggestable\(\"$convertedcat\"\, \'${language}\'\)\;
        } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo $listend
        ;;
      *) ;;
      esac
    fi
  else
    titleurl=${title//\"/\%22}
    titleurl=${title//\_/\%20}
    titlesql=${title//\"/\"\'\"\'\"}

    convertedtitle=$( echo $titleurl | sed -e 's/?/\%3F/g' )
    convertedtitle=$( echo $convertedtitle | sed -e 's/&/\%26/g' )
    echo "<h2><a href=\"http://ru.wikipedia.org/wiki/$convertedtitle\">$title</a></h2>"

    # for orphaned and other isolated articles we use different definitions.
    {
      echo "SELECT cat FROM ruwiki0 WHERE title=\"${convertedtitle// /_}\";"
    } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                      isotype=''

                      while read -r line
                        do handle_isotype $line
                      done

                      case "$isotype" in
                      '')
                        echo $r_notrecognized
                        ;;
                      '_1')
                        echo $r_orphaned
                        ;;
                      *)
                        echo "<h4>$isotype</h4>"
                        echo $r_isolated
                        ;;
                      esac

                      if [ "$isotype" != '' ]
                      then
                        suggestions
                      fi
                    }
               
    echo "<h3>$googleonwikipedia</h3>"
    echo "<IFRAME src=\"http://www.google.com/custom?hl=$interface&domains=ru.wikipedia.org&q=$titleurl&sitesearch=ru.wikipedia.org\" width=\"100%\" height=\"1500\" scrolling=\"auto\" frameborder=\"1\">"
    echo "Your user agent does not support frames or is currently configured not to display frames. However, you may <A href=\"http://www.google.com/custom?hl=$interface&domains=ru.wikipedia.org&q=$titleurl&sitesearch=ru.wikipedia.org\">seach with this link</A>."
    echo "</IFRAME>"
  fi;;
'disambig')
  echo "<br />$subclause1<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT title            \
                FROM isdis,               \
                     ruwiki0              \
                WHERE ruwiki0.id=isdis.id \
                ORDER BY title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_category "$line"
                    done
                  } 
  echo "</ol>"
  echo $listend
  ;;
'disambigcat')
  echo "<br />$subclause2<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT title,              \
                cnt                 \
                FROM sgdcatvolume0, \
                     categories     \
                WHERE cat=id        \
                ORDER BY cnt DESC   \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'disambig'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"

  ;;
'interlink')
  echo "<br />$subclause3<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT title            \
                FROM isres,               \
                     ruwiki0              \
                WHERE ruwiki0.id=isres.id \
                ORDER BY title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  ;;
'interlinkcat')
  echo "<br />$subclause4<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=interlinkcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=interlinkcat&shift=$shiftnext\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT title,              \
                cnt                 \
                FROM sglcatvolume0, \
                     categories     \
                WHERE cat=id        \
                ORDER BY cnt DESC   \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'interlink'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=interlinkcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=interlinkcat&shift=$shiftnext\">$next 100</a>"

  ;;
'translate')
  echo "<br />$subclause5<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT title             \
                FROM istres,               \
                     ruwiki0               \
                WHERE ruwiki0.id=istres.id \
                ORDER BY title ASC\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_category "$line"
                    done
                  }
  echo "</ol>"
  echo $listend

  ;;
'translatecat')
  echo "<br />$subclause6<br />"

  echo "<br />"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=translatecat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=translatecat&shift=$shiftnext\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT title,              \
                cnt                 \
                FROM sgtcatvolume0, \
                     categories     \
                WHERE cat=id        \
                ORDER BY cnt DESC   \
                LIMIT $((shift)),100\;
  } | $( sql ${dbserver} u_${usr}_golem_${language} ) 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'translate'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=translatecat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=translatecat&shift=$shiftnext\">$next 100</a>"

  ;;
*) ;;
esac

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
