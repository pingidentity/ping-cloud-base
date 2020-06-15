#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Creating enrichment volume folders..."

mkdir -p /enrichment-shared-volume/logs \
         /enrichment-shared-volume/tmp \
         /enrichment-shared-volume/elasticsearch-ilm-policies \
         /enrichment-shared-volume/elasticsearch-index-bootstraps \
         /enrichment-shared-volume/elasticsearch-index-templates \
         /enrichment-shared-volume/elasticsearch-role-bootstraps \
         /enrichment-shared-volume/enrichment-cache \
         /enrichment-shared-volume/kibana-config \
         /enrichment-shared-volume/logstash-config \
         /enrichment-shared-volume/logstash-search-templates \
         /enrichment-shared-volume/certs-config \
         /enrichment-shared-volume/certs

logger "INFO" "Folders created."

. "/scripts/done.sh"