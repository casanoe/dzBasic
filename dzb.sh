#!/bin/bash

# Description : gadget to send dzbasic command to domoticz

# prerequisite 1: jq and curl installed in your system
# prerequisite 2: dzBasic uservariable in Domoticz
# prerequisite 3: update DZURL with your Domoticz url

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
      curl -s "$DZURL/json.htm?type=command&param=getlog&lastlogtime=$TS&loglevel=2" > $TMP
      jq -r ".result[].message" $TMP
      rm $TMP
    fi
  done
exit 0
