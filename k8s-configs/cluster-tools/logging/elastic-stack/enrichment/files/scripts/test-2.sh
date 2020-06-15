#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

logger "INFO" "Reading $WAIT_FOR artifact..."
cat /test/$WAIT_FOR-artifact
logger "INFO" "Sleeping for 10 sec..."
sleep 10
logger "INFO" "Creating self artifact..."
echo "Artifact: $CONTAINER_NAME" >> /test/$CONTAINER_NAME-artifact
logger "INFO" "Starting sleep to be able to receive new commands..."

. "/scripts/done.sh"