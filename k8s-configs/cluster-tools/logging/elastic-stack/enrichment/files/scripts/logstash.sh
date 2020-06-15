#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Logstash started"

# export ELASTIC_USER_DECODED=$(echo $ELASTIC_USER | base64 -d)
# export ELASTIC_PASSWORD_DECODED=$(echo $ELASTIC_PASSWORD | base64 -d)
# export XPACK_MONITORING_ELASTICSEARCH_USERNAME=$(echo $ELASTIC_USER | base64 -d)
# export XPACK_MONITORING_ELASTICSEARCH_PASSWORD=$(echo $ELASTIC_PASSWORD | base64 -d)

# export XPACK_MANAGEMENT_ELASTICSEARCH_USERNAME=$(echo $ELASTIC_USER | base64 -d)
# export XPACK_MANAGEMENT_ELASTICSEARCH_PASSWORD=$(echo $ELASTIC_PASSWORD | base64 -d)

export XPACK_MONITORING_ELASTICSEARCH_USERNAME=elastic
export XPACK_MONITORING_ELASTICSEARCH_PASSWORD=3L@571C

export XPACK_MANAGEMENT_ELASTICSEARCH_USERNAME=elastic
export XPACK_MANAGEMENT_ELASTICSEARCH_PASSWORD=3L@571C

env

# /usr/share/logstash/bin/logstash --config.test_and_exit -f /usr/share/logstash/pipeline/logstash.conf

/usr/share/logstash/bin/logstash #-f /usr/share/logstash/pipeline/logstash.conf