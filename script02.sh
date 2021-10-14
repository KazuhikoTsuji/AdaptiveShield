#!/bin/sh

HOME=<Specify your home directory to work>
PATH=/usr/bin:/bin:/usr/local/bin

accountid=$(cat $HOME/accountid)
apikey=$(cat $HOME/apikey)
date=$(date '+%Y-%m-%d')
time=$(date '+%H-%M-%S')
mkdir -p $HOME/SecurityChecks/$date 2>/dev/null

request_uri="https://api.adaptive-shield.com/api/v1/accounts/$accountid/security_checks?offset=0&limit=500"
judge=0
while [ $judge -eq 0 ]
do
  curl -s --location -g --request GET $request_uri --header "Authorization: Token $apikey" --data-raw '' | jq -r >> $HOME/SecurityChecks/$date/All\_$date\_$time.json
  request_uri=$(tail -2 $HOME/SecurityChecks/$date/All\_$date\_$time.json | head -1 | grep "next_page_uri" | awk '{print $NF}' | tr -d \")
  judge=$(tail -2 $HOME/SecurityChecks/$date/All\_$date\_$time.json | head -1 | grep "next_page_uri" > /dev/null 2>&1; echo $?)
done

request_uri="https://api.adaptive-shield.com/api/v1/accounts/$accountid/integrations"
curl -s --location -g --request GET $request_uri --header "Authorization: Token $apikey" --data-raw '' | jq -r >> $HOME/tmp$$.json
jq -r ".data[] | select(.enabled==true).id" $HOME/tmp$$.json |\
while read LINE;
do
  saas_name=$(jq -r ".data[] | select(.id==\"$LINE\").saas_name" $HOME/tmp$$.json | sort | uniq)
  alias=$(jq -r ".data[] | select(.id==\"$LINE\").alias" $HOME/tmp$$.json | sort | uniq)
  jq -r ".data[] | select(.integration_id==\"$LINE\")" $HOME/SecurityChecks/$date/All\_$date\_$time.json >> $HOME/SecurityChecks/$date/$saas_name\_$alias\_$date\_$time.json
done

rm $HOME/tmp$$.json
