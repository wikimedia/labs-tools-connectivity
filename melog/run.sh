#!/bin/bash

while read line
do
	php -f ./actstact/solution.php $line
done < ./wikis.txt
