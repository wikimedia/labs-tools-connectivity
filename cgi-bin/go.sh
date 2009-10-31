#!/bin/bash

source ./allyouneed

#
# Standard page header
#
the_header

echo "<h1>$thish1</h1>"

#
# the search form
#
case $listby in
 'category')
  echo $example
  echo "<FORM action=\"./go.sh\" method=\"get\">"
  echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
  echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
  echo "<INPUT type=hidden name=\"listby\" value=\"$listby\">"
  if [ "$shift_url" != '' ]
  then
    echo "<INPUT type=hidden name=\"shift\" value=\"$shift\">"
  fi
  echo "<P><font color=red>$catnamereq: <INPUT name=category type=\"text\"> $activateform</font></P>"
  echo "</FORM>"
  ;;
 'creator')
  echo $example
  echo "<FORM action=\"./go.sh\" method=\"get\">"
  echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
  echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
  echo "<INPUT type=hidden name=\"listby\" value=\"$listby\">"
  echo "<P><font color=red>$unamereq: <INPUT name=user type=\"text\"> $activateform</font></P>"
  echo "</FORM>"
  ;;
 'suggest' | 'suggest,category' | 'suggest,category,foreign' | 'suggest,foreign' | 'suggest,foeign,category' | 'suggest,title')
  echo "<FORM action=\"./go.sh\" method=\"get\">"
  echo "<INPUT type=hidden name=\"interface\" value=\"$interface\">"
  echo "<INPUT type=hidden name=\"language\" value=\"$language\">"
  echo "<INPUT type=hidden name=\"listby\" value=\"suggest,title\">"
  echo "<P><font color=red>$ianamereq: <INPUT name=title type=\"text\"> $activateform</font></P>"
  echo "</FORM>"
  ;;
esac

source ./$listby

#
# Standard page footer
#
the_footer
