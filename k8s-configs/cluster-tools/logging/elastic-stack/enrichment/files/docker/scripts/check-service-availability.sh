#!/usr/bin/env sh

source /scripts/logger.sh

service_status="red"

while [ "$service_status" != "$DESIRED_STATUS" ]
do
  logger "INFO" "Service isn't ready yet, retry..."
  sleep 3
  service_health=$(curl -s --insecure $SERVICE_URL:$SERVICE_PORT/_cluster/health)
  service_status=$(expr "$service_health" : '.*"status":"\([^"]*\)"')
done

logger "INFO" "Service became ready."