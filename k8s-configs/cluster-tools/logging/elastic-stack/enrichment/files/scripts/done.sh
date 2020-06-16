#!/usr/bin/env sh

logger "INFO" "Creating flag file..."
touch /enrichment-shared-volume/tmp/$CONTAINER_NAME
logger "INFO" "$CONTAINER_NAME: Job done!"