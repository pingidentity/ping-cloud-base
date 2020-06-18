#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Starting Logstash..."

/usr/share/logstash/bin/logstash -f /usr/share/logstash/pipeline/logstash.conf