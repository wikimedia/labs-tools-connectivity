#!/bin/bash

source ./allyouneed

#
# Standard page header
#
the_header

if [ "$neverrun" = '' ]
then
  if [ "$listby" = 'categoryspruce' ] || [ $disambiguating_templates -gt 0 ]
  then
    if [ "$listby" != 'disambig,template' ] || [ "$template_doc" != '' ]
    then
      the_content
    else
      echo "<h2><font color=red>$templatedoc_improperly_configured <a href='http://$language.wikipedia.org/wiki/${wiknspref}${prjp}/TemplateDoc'>[[${wiknspref}${prjp}/TemplateDoc]]</a>.</font></h2>"
    fi
  else
    echo "<h2><font color=red>$disambiguationspage_improperly_configured</font></h2>"
  fi
else
  echo "<h2><font color=red>$neverrun</font></h2>"
fi  

#
# Standard page footer
#
the_footer
