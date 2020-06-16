#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Logstash started"

export XPACK_MONITORING_ELASTICSEARCH_USERNAME=elastic
export XPACK_MONITORING_ELASTICSEARCH_PASSWORD=`cat /enrichment-shared-volume/passwords/elastic`

# /usr/share/logstash/bin/logstash --config.test_and_exit -f /usr/share/logstash/pipeline/logstash.conf

/usr/share/logstash/bin/logstash #-f /usr/share/logstash/pipeline/logstash.conf