#!/bin/bash
# prerequisite 1: jq and curl in your os
# prerequisite 2: dzBasic uservariable in Domoticz
# Description : gadget to send dzbasic command to domoticz
# Version: 1.0

DZURL="http://192.168.1.18:8080"

PROMPT='DZB> '
TMP='dzbshtmp'

while :
  do
    echo -n "$PROMPT"
    read line
    if [ "$line" = "exit" ]
    then
      exit 0
    fi
    if [ "$line" != "" ]
    then
      TS=$(date +"%s")
      curl -s --data-urlencode "vvalue=$line" "$DZURL/json.htm?type=command&param=updateuservariable&vname=dzBasic&vtype=2" > $TMP
      jq -r ".status" $TMP
      curl -s "http://192.168.1.18:8080/json.htm?type=command&param=getlog&lastlogtime=$TS&loglevel=2" > $TMP
      jq -r ".result[].message" $TMP
      rm $TMP
    fi
  done
exit 0
