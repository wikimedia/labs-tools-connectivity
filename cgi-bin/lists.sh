#!/bin/bash

script="lists"
source ./common

source ./common.$interface
source ./$script.$interface
source ./common2

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
how_actual categoryspruce

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

echo "<p>$description</p>"

echo "<h3><a href=\"./suggest.sh?language=$language&interface=$interface&listby=disambig\">$fl_disambig</a></h3>"

echo "<h3><a href=\"./suggest.sh?language=$language&interface=$interface&listby=interlink\">$fl_interlink</a></h3>"

echo "<h3><a href=\"./suggest.sh?language=$language&interface=$interface&listby=translate\">$fl_translate</a></h3>"

cat << EOM
</td>
</tr>
</table>

 </body>
</html>
EOM
