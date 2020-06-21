#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Copying mounted configmaps data into correspond folders started."

cp /enrichment-cache/* /enrichment-shared-volume/enrichment-cache/

if [ "$(ls -A /enrichment-shared-volume/enrichment-cache/)" ]; then
    logger "INFO" "Files was copied successfully."
else
    logger "ERROR" "Enrichment files wasn't copied, something went wrong."
    exit 1
fi

logger "INFO" "Starting enrichment script running..."
python /scripts/enrichment.py

chown -R 1000:1000 /enrichment-shared-volume

logger "INFO" "$CONTAINER_NAME: Job done!"