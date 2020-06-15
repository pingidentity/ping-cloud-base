#!/usr/bin/env sh

logger "INFO" "Waiting for $WAIT_FOR becomes ready..."
until test -f "/enrichment-shared-volume/tmp/${WAIT_FOR}";
do
  logger "INFO" "$WAIT_FOR is not ready yet. Retry..."
  sleep 2
done
logger "INFO" "$WAIT_FOR is ready now. Execution starts..."
# rm -rf /enrichment-shared-volume/tmp/$WAIT_FOR