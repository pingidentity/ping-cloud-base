#!/usr/bin/env sh

logger "INFO" "$CONTAINER_NAME: Job done!"
logger "INFO" "Creating flag file..."
touch /enrichment-shared-volume/tmp/$CONTAINER_NAME
# test -f "/test/$CONTAINER_NAME" && exit 0 || exit 1
ls /enrichment-shared-volume/tmp | grep $CONTAINER_NAME