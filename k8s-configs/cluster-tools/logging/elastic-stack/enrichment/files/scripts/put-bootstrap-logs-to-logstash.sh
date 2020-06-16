#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Starting to pushing logs into logstash..."

# HERE SHOULD BE LOGS SHIPPING FUNCTION

logger "INFO" "Logs was pushed."

. "/scripts/done.sh"