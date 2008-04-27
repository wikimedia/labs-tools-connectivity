#!/bin/bash

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
  echo -ne "<a href=\"./suggest.sh?interface=en&title=$title&listby=$listby&category=$category&suggest=$suggest\">[[en:]]</a> [[ru:]]"
else
  echo -ne "[[en:]] <a href=\"./suggest.sh?interface=ru&title=$title&listby=$listby&category=$category&suggest=$suggest\">[[ru:]]</a>"
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
if [ "$listby" = '' ] && [ "$category" != '' ]
then
  echo "<li><a id=seealso href=\"./category.sh?interface=$interface&category=$category\">${catns}:$category</a></li>"
fi
if [ "$listby$category" = '' ]
then
  if [ "$title" != '' ]
  then
    echo "<li><a href=\"./suggest.sh?interface=$interface\">$allsuggestions</a></li>"
    echo "<ul>"
    echo "<li>$fortext <font color=red>$title</font></li>"
  else
    echo "<li><font color=red>$allsuggestions</font></li>"
    echo "<ul>"
  fi
else
  echo "<li><a href=\"./suggest.sh?interface=$interface\">$allsuggestions</a></li>"
  echo "<ul>"
fi
if [ "$listby" = 'disambigcat' ]
then
  echo "<li><font color=red>$resolvedisambigs</font></li>"
else
  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=disambigcat\">$resolvedisambigs</a></li>"
fi
if [ "$listby" = '' ] && [ "$category" != '' ]
then
  if [ "$suggest" = 'disambig' ]
  then
    echo "<ul><li><font color=red>${catns}:$category</font></li></ul>"
  else
    echo "<ul><li><a id=seealso href=\"./suggest.sh?interface=$interface&category=$category&suggest=disambig\">${catns}:$category</a></li></ul>"
  fi
fi
echo "<li>$justlink</li>"
echo "<ul>"
if [ "$listby" = 'interlinkcat' ]
then
echo "<li><font color=red>$parttranslate</font></li>"
else
  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=interlinkcat\">$parttranslate</a></li>"
fi
if [ "$listby" = '' ] && [ "$category" != '' ]
then
  if [ "$suggest" = 'interlink' ]
  then
    echo "<ul><li><font color=red>${catns}:$category</font></li></ul>"
  else
    echo "<ul><li><a id=seealso href=\"./suggest.sh?interface=$interface&category=$category&suggest=interlink\">${catns}:$category</a></li></ul>"
  fi
fi
if [ "$listby" = 'translatecat' ]
then
  echo "<li><font color=red>$translatenlink</font></li>"
else
  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=translatecat\">$translatenlink</a></li>"
fi
if [ "$listby" = '' ] && [ "$category" != '' ]
then
  if [ "$suggest" = 'translate' ]
  then
    echo "<ul><li><font color=red>${catns}:$category</font></li></ul>"
  else
    echo "<ul><li><a id=seealso href=\"./suggest.sh?interface=$interface&category=$category&suggest=translate\">${catns}:$category</a></li></ul>"
  fi
fi
echo "</ul>"
echo "</ul>"
echo "</ul>"
echo -ne "<li><b><a href=\"../lists"
if [ "$interface" = 'ru' ]
then
  echo -ne "ru"
fi
echo ".html\">$wholelist</a></b></li>"
case "$listby" in
 'disambig')
   echo "<ul><li><font color=red>$resolvedisambigs</font></li></ul>"
   ;;
 'interlink')
   echo "<ul><li><font color=red>$parttranslate</font></li></ul>"
   ;;
 'translate')
   echo "<ul><li><font color=red>$translatenlink</font></li></ul>"
   ;;
*) ;;
esac
#echo "<li><b>$wholelist</b></li>"
#echo "<ul>"
#if [ "$listby" = 'disambig' ]
#then
#  echo "<li><font color=red>$resolvedisambigs</font></li>"
#else
#  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=disambig\">$resolvedisambigs</a></li>"
#fi
#echo "<li>$justlink</li>"
#echo "<ul>"
#if [ "$listby" = 'interlink' ]
#then
#  echo "<li><font color=red>$parttranslate</font></li>"
#else
#  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=interlink\">$parttranslate</a></li>"
#fi
#if [ "$listby" = 'translate' ]
#then
#  echo "<li><font color=red>$translatenlink</font></li>"
#else
#  echo "<li><a href=\"./suggest.sh?interface=$interface&listby=translate\">$translatenlink</a></li>"
#fi
#echo "</ul>"
#echo "</ul>"
echo "<li><b><a href=\"http://ru.wikipedia.org/w/index.php?title=$prjurl/bytypes\">$byclastertype</a></b></li>"
echo "<ul><li><a href=\"http://ru.wikipedia.org/w/index.php?title=$orphurl\">$orphanes</a></li></ul>"
echo "<li><b><a href=\"./creators.sh?interface=$interface\">$bycreator</a></b></li>"
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
      case $suggest in
      'disambig')
        echo "<br />$submenu1desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           isdis                               \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 a2i_to=title                  \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo $listend
        ;;
      'interlink')
        echo "<br />$submenu2desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           isres                               \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 isolated=id                   \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
                          while read -r line
                            do handle_category "$line"
                          done
                        }
        echo "</ol>"
        echo $listend
        ;;
      'translate')
        echo "<br />$submenu3desc <a href=\"http://ru.wikipedia.org/w/index.php?title=Category:$categoryurl\">$category</a>"
        convertedcat=$( echo $category | sed -e 's/ /_/g' )

        echo "<ol>"
        {
          echo SELECT DISTINCT title                           \
                      FROM ruwiki_p.categorylinks,             \
                           ruwiki0,                            \
                           istres                              \
                           WHERE id=cl_from and                \
                                 cl_to=\'${convertedcat}\' and \
                                 isolated=id                   \
                           ORDER BY title ASC\;
        } | $sql 2>&1 | { 
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
    titlesql=${title//\"/\"\'\"\'\"}

    convertedtitle=$( echo $titleurl | sed -e 's/?/\%3F/g' )
    convertedtitle=$( echo $convertedtitle | sed -e 's/&/\%26/g' )
    echo "<h2><a href=\"http://ru.wikipedia.org/wiki/$convertedtitle\">$title</a></h2>"
    echo "<h3>$sggclause0</h3>"
    echo "$sggclause1<br />"
    echo "<font color=red><ul><li>$sggclause2 $sggclause3</li></ul></font>"

    convertedtitle=$( echo $titlesql | sed -e 's/ /_/g' )
    echo "<ol>"
    {
      echo CALL dsuggest\(\"$convertedtitle\"\)\;
    } | $sql 2>&1 | {
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
    } | $sql 2>&1 | {
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
    } | $sql 2>&1 | { 
                      lang=''
                      while read -r line
                        do handle_trns "$line"
                      done
                    }
    echo "</ol>"
    echo $listend

    echo "<h3>$googleonwikipedia</h3>"
    echo "<IFRAME src=\"http://www.google.com/custom?hl=$interface&domains=ru.wikipedia.org&q=$titleurl&sitesearch=ru.wikipedia.org\" width=\"100%\" height=\"1500\" scrolling=\"auto\" frameborder=\"1\">"
    echo "<font color=red>Your user agent does not support frames or is currently configured not to display frames. However, you may <A href=\"http://www.google.com/custom?hl=$interface&domains=ru.wikipedia.org&q=$titleurl&sitesearch=ru.wikipedia.org\">seach with this link</A>."
    echo "</IFRAME>"
  fi;;
'disambig')
  echo "<br />$subclause1<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT a2i_to \
                FROM isdis        \
                ORDER BY a2i_to ASC\;
  } | $sql 2>&1 | {
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
    echo SELECT cv_title,                 \
                cv_dsgcount               \
                FROM catvolume0           \
                ORDER BY cv_dsgcount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
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
    echo SELECT DISTINCT title    \
                FROM isres,       \
                     ruwiki0      \
                WHERE id=isolated \
                ORDER BY title ASC\;
  } | $sql 2>&1 | {
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
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT cv_title,                 \
                cv_ilscount               \
                FROM catvolume0           \
                ORDER BY cv_ilscount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'interlink'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"

  ;;
'translate')
  echo "<br />$subclause5<br />"

  echo "<ol>"
  {
    echo SELECT DISTINCT title    \
                FROM istres,      \
                     ruwiki0      \
                WHERE id=isolated \
                ORDER BY title ASC\;
  } | $sql 2>&1 | {
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
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"
  echo "<ol start=$((shift+1))>"
  {
    echo SELECT cv_title,                 \
                cv_tlscount               \
                FROM catvolume0           \
                ORDER BY cv_tlscount DESC \
                LIMIT $((shift)),100\;
  } | $sql 2>&1 | { 
                    while read -r line
                      do handle_catlist "$line" 'translate'
                    done
                  }
  echo "</ol>"
  if [ $((shift)) -gt 0 ]
  then
    echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftprev\">$previous 100</a> "
  fi
  echo "<a href=\"./suggest.sh?interface=$interface&listby=disambigcat&shift=$shiftnext\">$next 100</a>"

  ;;
*) ;;
esac

cat << EOM
</td>
</tr>
</table>

 <body>
</html>
EOM
