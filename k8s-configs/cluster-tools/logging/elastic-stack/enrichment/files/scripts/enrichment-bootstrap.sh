#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

# Simple script to load elasticsearch templates, ilm, policies, and all other required objects into the healthy cluster 
# indexes and kibana saved ndjson.

es_status="red"
kib_status="red"

ELASTIC_USER_DECODED=$(echo $ELASTIC_USER | base64 -d)
ELASTIC_PASSWORD_DECODED=$(echo $ELASTIC_PASSWORD | base64 -d)

logger "INFO" "Starting ElasticSearch Loading Process..."

#Wait for ElasticSearch API to go Green before importing templates
while [ "$es_status" != "green" ]
do
  logger "INFO" "Status Not Green Yet"
  sleep 3

  ###
  ###
  curl -s -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED --insecure $ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_cluster/health
  health=$(curl -s -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED --insecure $ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_cluster/health)
  #health=$(curl -s --insecure $ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_cluster/health)
  ###
  ###

  es_status=$(expr "$health" : '.*"status":"\([^"]*\)"')
  echo $health
done

#Load in Index Lifecycle polices
logger "INFO" "Loading! -- ElasticSearch ILM Policies"
for f in /enrichment-shared-volume/elasticsearch-ilm-policies/*.json
do	
  logger "INFO" "Processing index lifecycle policy file (full path) $f "
  fn=$(basename $f)
  n="${fn%.*}"

  logger "INFO" "Processing file name $n "

  ###
  ###
  curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_ilm/policy/$n?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
  #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_ilm/policy/$n?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
  ###
  ###

done

#Load in Index Templates This includes mappings, settings, etc.
logger "INFO" "Loading! -- ElasticSearch Index Templates"
for f in /enrichment-shared-volume/elasticsearch-index-templates/*.json
do	
  logger "INFO" "Processing index template file (full path) $f "
  fn=$(basename $f)
  n="${fn%.*}"

  logger "INFO" "Processing file name $n "

  ###
  ###
  curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_template/$n?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
  #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_template/$n?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
  ###
  ###

done

#Bootstrap all required indexes
logger "INFO" "Loading! -- Bootstraping Indexes"
for f in /enrichment-shared-volume/elasticsearch-index-bootstraps/*.json
do	
  logger "INFO" "Processing index bootstrap file (full path) $f "
  fn=$(basename $f)
  n="${fn%.*}"

  logger "INFO" "Processing file name $n "

  ###
  ###
  curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/$n-000001?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
  #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/$n-000001?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
  ###
  ###

done

#Bootstrap all required roles
logger "INFO" "Loading! -- Bootstraping Roles"
for f in /enrichment-shared-volume/elasticsearch-role-bootstraps/*.json
do  
  logger "INFO" "Processing role bootstrap file (full path) $f "
  fn=$(basename $f)
  n="${fn%.*}"

  logger "INFO" "Processing file name $n "

  ###
  ###
  curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_security/role_mapping/$n" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
  #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_security/role_mapping/$n" --insecure -H 'Content-Type: application/json' -d"@$f"
  ###
  ###

done

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

logger "INFO" "Bootstrap Execution complete."

. "/scripts/done.sh"