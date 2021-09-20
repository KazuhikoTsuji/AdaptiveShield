#!/bin/sh

separator='------------'
accountid=$(cat accountid)
apikey=$(cat apikey)

request_uri="https://api.adaptive-shield.com/api/v1/accounts/$accountid/security_checks?offset=0&limit=500"
judge=0
while [ $judge -eq 0 ]
do
  curl -s --location -g --request GET $request_uri --header "Authorization: Token $apikey" --data-raw '' | jq -r >> tmp01$$.json
  request_uri=$(tail -2 tmp01$$.json | head -1 | grep "next_page_uri" | awk '{print $NF}' | tr -d \")
  judge=$(tail -2 tmp01$$.json | head -1 | grep "next_page_uri" > /dev/null 2>&1; echo $?)
done

date=$(date '+%Y-%m-%d')
time=$(date '+%H:%M:%S')
connected_apps=$(jq '.data[].saas_name' tmp01$$.json | sort | uniq | wc -l)
connected_integrations=$(jq '.data[].integration_id' tmp01$$.json | sort | uniq | wc -l)
mkdir -p ./SecurityChecks/$date 2>/dev/null

echo "$separator" > ./SecurityChecks/$date/DailySummary_"$date"
echo "Date: $date" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "Time: $time" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "Connected Apps: $connected_apps" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "Connected Integrations: $connected_integrations" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "$separator" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "#SaaS Name:\tCheck Items" >> ./SecurityChecks/$date/DailySummary_"$date"

jq -r '.data[].saas_name' tmp01$$.json | sort | uniq |\
while read LINE;
do
  duplicate=$(jq -r ".data[] | select(.saas_name==\"$LINE\").integration_id" tmp01$$.json | sort | uniq | wc -l)
  number=$(($(jq -r ".data[] | select(.saas_name==\"$LINE\").name" tmp01$$.json | wc -l)/$duplicate))
  echo "$LINE:\t$number" >> ./SecurityChecks/$date/DailySummary_"$date"
done

echo "$separator" >> ./SecurityChecks/$date/DailySummary_"$date"
echo "#SaaS Name\tAlias:\tSum(Passed/Failed/Stale/Can't Run)" >> ./SecurityChecks/$date/DailySummary_"$date"
sum=$(jq -r ".data[].integration_id" tmp01$$.json | wc -l)
passed=$(jq -r ".data[] | select(.status==\"Passed\").integration_id" tmp01$$.json | wc -l)
failed=$(jq -r ".data[] | select(.status==\"Failed\").integration_id" tmp01$$.json | wc -l)
stale=$(jq -r ".data[] | select(.status==\"Stale\").integration_id" tmp01$$.json | wc -l)
cantrun=$(jq -r ".data[] | select(.status==\"Can't Run\").integration_id" tmp01$$.json | wc -l)
echo "Total\t- :\t$sum ($passed/$failed/$stale/$cantrun)" >> ./SecurityChecks/$date/DailySummary_"$date"
request_uri="https://api.adaptive-shield.com/api/v1/accounts/$accountid/integrations"
curl -s --location -g --request GET $request_uri --header "Authorization: Token $apikey" --data-raw '' | jq -r >> tmp02$$.json
jq -r ".data[] | select(.enabled==true).id" tmp02$$.json |\
while read LINE;
do
  saas_name=$(jq -r ".data[] | select(.id==\"$LINE\").saas_name" tmp02$$.json | sort | uniq)
  alias=$(jq -r ".data[] | select(.id==\"$LINE\").alias" tmp02$$.json | sort | uniq)
  sum=$(jq -r ".data[] | select(.integration_id==\"$LINE\").integration_id" tmp01$$.json | wc -l)
  passed=$(jq -r ".data[] | select(.integration_id==\"$LINE\" and .status==\"Passed\").integration_id" tmp01$$.json | wc -l)
  failed=$(jq -r ".data[] | select(.integration_id==\"$LINE\" and .status==\"Failed\").integration_id" tmp01$$.json | wc -l)
  stale=$(jq -r ".data[] | select(.integration_id==\"$LINE\" and .status==\"Stale\").integration_id" tmp01$$.json | wc -l)
  cantrun=$(jq -r ".data[] | select(.integration_id==\"$LINE\" and .status==\"Can't Run\").integration_id" tmp01$$.json | wc -l)
  echo "$saas_name\t$alias:\t$sum ($passed/$failed/$stale/$cantrun)" >> ./SecurityChecks/$date/DailySummary_"$date"
done

rm tmp0{1..2}$$.json
