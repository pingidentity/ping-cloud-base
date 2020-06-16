#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Creating enrichment volume folders..."

mkdir -p /enrichment-shared-volume/logs \
         /enrichment-shared-volume/tmp \
         /enrichment-shared-volume/enrichment-cache \
         /enrichment-shared-volume/certs \
         /enrichment-shared-volume/secrets

chown -r 1000:1000 /enrichment-shared-volume

logger "INFO" "Folders created."

. "/scripts/done.sh"

sleep 9999999999;