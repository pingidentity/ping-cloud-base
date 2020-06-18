#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Starting Kibana..."

/usr/share/kibana/bin/kibana

. "/scripts/done.sh"