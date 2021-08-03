#!/bin/bash

i_a3m="$1"
o_ss="$2"

ID=$(basename $i_a3m .a3m).tmp

if [ ! -s $ID.horiz ]
then
	echo $ID.horiz" isn't exist!"
	exit
fi

(
echo ">ss_pred"
grep "^Pred" $ID.horiz | awk '{print $2}'
echo ">ss_conf"
grep "^Conf" $ID.horiz | awk '{print $2}'
) | awk '{if(substr($1,1,1)==">") {print "\n"$1} else {printf "%s", $1}} END {print ""}' | sed "1d" > $o_ss

rm $ID.*
