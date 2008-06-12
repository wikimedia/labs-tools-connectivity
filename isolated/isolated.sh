 #
 # Works on the Toolserver.
 #
 # Authors: [[:ru:user:Mashiah Davidson]], still alone
 #
 # Purpose: 
 #
 #      [[:en:Connectivity (graph theory)|Connectivity]] analysis script for
 #      [[:ru:|Russian Wikipedia]] and probably others if ready to introduce
 #      some of guidances like
 #            - what is an article, 
 #            - what is a relevant link,
 #            - what is an isolated/orphaned article,
 #            - what is a dead-end article,
 #            - what is a chronological article,
 #            - what is a colloborative list of article names
 #            - what the disambiguation is and so on.
 # 
 # Use: Bash command prompt (or better use with screen)
 #
 #      ./isolated.sh           - to run all the analysis supported
 #      ./isolated.sh mr        - to enable multiple redirects resolving
 #      ./isolated.sh stat      - to enable cluster chains statistics upload
 #      ./isolated.sh mr stat   - as we do in Ruwiki
 #
 # Default output:
 #
 #      1. Useful informative output on stdout
 #      2. Files archieved to today.7z at some stage:
 #         - Wrong redirects list                        (<ts>.wr.txt)
 #         - Dead end pages not yet templated            (<ts>.deset.txt) 
 #         - Articles with links still marked as deadend (<ts>.derem.txt)
 #         - Isolated articles not yet templated         (<ts>.<chain>.txt)
 #         - Articles still marked as isolated           (<ts>.orem.txt)
 #      3. Files archieved to info.7z at some stage:
 #         - Multiple redirects list                     (<ts>.mr.info)
 #      4. Files archieved to stat.7z at some stage:
 #         - Claster chains for zero namespace redirects (<ts>.redirects.stat)
 #         - Claster chains for articles                 (<ts>.articles.stat)
 #         - Claster chains for categories               (<ts>.categories.stat)
 #      5. Redirects in category namespace - if any      (<ts>.r.txt)
 #
 # Error handling:
 #
 #      See debug.log if created or last file modified.
 #
 # <pre>

#!/bin/bash

do_templates=0
do_stat=0
do_mr=0
if [ "$1" = "templates" ] || [ "$2" = "templates" ] || [ "$3" = "templates" ]
then
  do_templates=1
fi
if [ "$1" = "mr" ] || [ "$2" = "mr" ] || [ "$3" = "mr" ]
then
  do_mr=1
fi
if [ "$1" = "stat" ] || [ "$2" = "stat" ] || [ "$3" = "stat" ]
then
  do_stat=1
fi

dbhost="sql-s3"
dbhost2="sql-s2"
myusr=$( cat ~/.my.cnf | grep 'user ' | sed 's/^user = \([a-z]*\)$/\1/' )
sql="mysql --host=$dbhost -A --database=u_${myusr} -n -b -N --connect_timeout=10"
sql2="mysql --host=$dbhost2 -A --database=u_${myusr} -n -b -N --connect_timeout=10"

rm -f ./*.info ./*.txt ./*.stat debug.log no_stat.log no_templates.log no_mr.log stats_done.log

time { 
  {

    #
    # Enable/disable informative output, such as current sets of
    # dead end articles or isolated chains of various types.
    #
    set @enable_informative_output=0;

    cat handle.sql
    cat replag.sql
    cat namespacer.sql
    cat categorizer.sql
    cat redirector.sql
    cat disambig.sql
    cat deadlocktor.sql
    cat templator.sql
    cat isolated.sql
    cat iwikispy.sql
    cat suggestor.sql
    cat creatorizer.sql
    cat cgi.sql

    echo 'CALL actual_replag();'

    #
    # Categorizer setup, prefetch categories namespace (14)
    # and holds categories list.
    #
    # Creates nr14, r14 and categories.
    #
    echo 'CALL categories();'

    #
    # Choose the right limit for recursion depth allowed.
    # Set the recursion depth to 255 for the first run
    # and then set it e.g. the maximal clusters chain length doubled.
    #

    echo "SET max_sp_recursion_depth=10;"

#    echo "SET @@max_heap_table_size=16777216;"
#    echo "SET @@max_heap_table_size=33554432;"
#    echo "SET @@max_heap_table_size=67108864;"
#    echo "SET @@max_heap_table_size=134217728;"
#    echo "SET @@max_heap_table_size=268435456;"
    echo "SET @@max_heap_table_size=536870912;"
#     echo "SET @@max_heap_table_size=1073741824;"

    #
    # Analyze zero namespace connectivity. Limit claster sizes by 10.
    #
    echo 'CALL zero_namespace_connectivity( 20 );'


    echo 'CALL replag();'

    #
    # Choose the right limit for recursion depth allowed.
    # Set the recursion depth to 255 for the first run
    # and then set it e.g. the maximal clusters chain length doubled.
    #
    echo "SET max_sp_recursion_depth=255;"

    #
    # Analyze categorytree namespace connectivity and prepare categoryspruce.
    # No limit on claster size.
    #
    echo 'CALL categorytree_connectivity( 0 );'

#    echo "SET @@max_heap_table_size=16777216;"
#    echo "SET @@max_heap_table_size=33554432;"
#    echo "SET @@max_heap_table_size=67108864;"
#    echo "SET @@max_heap_table_size=134217728;"
#    echo "SET @@max_heap_table_size=268435456;"
#    echo "SET @@max_heap_table_size=536870912;"
    echo "SET @@max_heap_table_size=1073741824;"

    #
    # Isolated by category,
    # Suggestor,
    # Creatorizer.
    #
    echo 'CALL zero_namespace_postponed_tools();'
  } | $sql 2>&1 | ./handle.sh $1 $2 $3
}

# </pre>