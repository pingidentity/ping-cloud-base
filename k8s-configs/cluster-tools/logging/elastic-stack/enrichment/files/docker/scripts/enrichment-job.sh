#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Starting enrichment script running..."
python /scripts/enrichment.py

chown -R 1000:1000 /enrichment-shared-volume

logger "INFO" "$CONTAINER_NAME: Job done!"