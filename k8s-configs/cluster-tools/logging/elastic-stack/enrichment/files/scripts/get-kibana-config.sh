#!/usr/bin/env sh

source /scripts/logger.sh

# HERE SHOULD BE FUNCTION THAT OBTAINS KIBANA DASHBOARD TEMPLATE

#kib_status="red"

#Wait for Kibana API to go Green before importing saved objects
# echo "Waiting for Kibana status green, prior to loading saved objects..."
# while [ "$kib_status" != "Looking good" ]
# do
#   echo "Status Not Looking green Yet Kibana"
#   sleep 3

#   ###
#   ###
#   #health=$(curl -s -u elastic:$ELASTIC_PASSWORD --insecure https://kibana:5601/api/status)
#   health=$(curl -s --insecure $KIBANA_URL:$KIBANA_PORT/api/status)
#   ###
#   ###

#   echo $health
#   kib_status=$(expr "$health" : '.*"nickname":"\([^"]*\)"')
# done
# echo "Loading! -- Kibana Saved Objects."

###
###
#curl -X POST "https://kibana:5601/api/saved_objects/_import" --insecure -u elastic:$ELASTIC_PASSWORD -H "kbn-xsrf: true" --form file="@/usr/share/elasticsearch/config/kibana_config/kib_base.ndjson"
#curl -X POST "$KIBANA_URL:$KIBANA_PORT/api/saved_objects/_import" --insecure -H "kbn-xsrf: true" --form file="@/usr/share/elasticsearch/config/kibana_config/kib_base.ndjson"
###
###

. "/scripts/done.sh"