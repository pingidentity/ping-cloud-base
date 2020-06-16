#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

# Simple script to load elasticsearch templates, ilm, policies, and all other required objects into the healthy cluster.

es_status="red"

####
export ELASTIC_USER="elastic"
export ELASTIC_PASSWORD=`cat /enrichment-shared-volume/passwords/elasticsearch`

export ELASTICSEARCH_URL="http://127.0.0.1"
export ELASTICSEARCH_PORT="9200"
####

logger "INFO" "Starting ElasticSearch Loading Process..."

# #Wait for ElasticSearch API to go Green before importing templates
# while [ "$es_status" != "green" ]
# do
#   logger "INFO" "Status Not Green Yet"
#   sleep 3

#   ###
#   ###
#   health=$(curl -s -u $ELASTIC_USER:$ELASTIC_PASSWORD --insecure $ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_cluster/health)
#   #health=$(curl -s --insecure $ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_cluster/health)
#   ###
#   ###

#   es_status=$(expr "$health" : '.*"status":"\([^"]*\)"')
#   echo $health
# done

# #Load in Index Lifecycle polices
# logger "INFO" "Loading! -- ElasticSearch ILM Policies"
# for f in /usr/share/elasticsearch/data/ilm-policies/*.json
# do	
#   logger "INFO" "Processing index lifecycle policy file (full path) $f "
#   fn=$(basename $f)
#   n="${fn%.*}"

#   logger "INFO" "Processing file name $n "

#   ###
#   ###
#   curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_ilm/policy/$n?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
#   #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_ilm/policy/$n?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
#   ###
#   ###

# done

# #Load in Index Templates This includes mappings, settings, etc.
# logger "INFO" "Loading! -- ElasticSearch Index Templates"
# for f in /usr/share/elasticsearch/data/index-templates/*.json
# do	
#   logger "INFO" "Processing index template file (full path) $f "
#   fn=$(basename $f)
#   n="${fn%.*}"

#   logger "INFO" "Processing file name $n "

#   ###
#   ###
#   curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_template/$n?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
#   #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_template/$n?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
#   ###
#   ###

# done

# #Bootstrap all required indexes
# logger "INFO" "Loading! -- Bootstraping Indexes"
# for f in /usr/share/elasticsearch/data/index-bootstraps/*.json
# do	
#   logger "INFO" "Processing index bootstrap file (full path) $f "
#   fn=$(basename $f)
#   n="${fn%.*}"

#   logger "INFO" "Processing file name $n "

#   ###
#   ###
#   curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/$n-000001?pretty" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
#   #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/$n-000001?pretty" --insecure -H 'Content-Type: application/json' -d"@$f"
#   ###
#   ###

# done

# #Bootstrap all required roles
# logger "INFO" "Loading! -- Bootstraping Roles"
# for f in /usr/share/elasticsearch/data/role-bootstraps/*.json
# do  
#   logger "INFO" "Processing role bootstrap file (full path) $f "
#   fn=$(basename $f)
#   n="${fn%.*}"

#   logger "INFO" "Processing file name $n "

#   ###
#   ###
#   curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_security/role_mapping/$n" --insecure -u $ELASTIC_USER_DECODED:$ELASTIC_PASSWORD_DECODED -H 'Content-Type: application/json' -d"@$f"
#   #curl -X PUT "$ELASTICSEARCH_URL:$ELASTICSEARCH_PORT/_security/role_mapping/$n" --insecure -H 'Content-Type: application/json' -d"@$f"
#   ###
#   ###

# done

logger "INFO" "Bootstrap Execution complete."

. "/scripts/done.sh"