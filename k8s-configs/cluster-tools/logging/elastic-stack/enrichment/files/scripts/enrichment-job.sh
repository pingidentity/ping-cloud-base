#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/install-dependencies.sh"

logger "INFO" "Starting enrichment script running..."
python /scripts/enrichment.py

chown -R 1000:1000 /enrichment-shared-volume

/scripts/put-logs-to-logstash.sh -f

. "/scripts/done.sh"