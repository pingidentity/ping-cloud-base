#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Elasticsearch started"

env

ls -l /usr/share/elasticsearch/data/config

/usr/share/elasticsearch/bin/elasticsearch

sleep 999999999999

# 3L@571C

# kubectl exec es-cluster-0 -c elasticsearch -n elastic-stack-logging -- curl -u elastic:M0xANTcxQwo= https://localhost:9200 --key /enrichment-shared-volume/certs/elasticsearch/elasticsearch.key --cert /enrichment-shared-volume/certs/elasticsearch/elasticsearch.crt --cacert /enrichment-shared-volume/certs/ca/ca.crt -v

# kubectl exec es-cluster-0 -c elasticsearch -n elastic-stack-logging -- curl -u elastic:M0xANTcxQwo= https://localhost:9200 -k

# kubectl exec es-cluster-0 -c elasticsearch -n elastic-stack-logging -- curl https://localhost:9200 --key /enrichment-shared-volume/certs/elasticsearch/elasticsearch.key --cert /enrichment-shared-volume/certs/elasticsearch/elasticsearch.crt --cacert /enrichment-shared-volume/certs/ca/ca.crt -v