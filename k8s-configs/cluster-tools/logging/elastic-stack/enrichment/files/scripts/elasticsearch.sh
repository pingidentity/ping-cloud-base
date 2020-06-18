#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Starting Elasticsearch..."

for file in /usr/share/elasticsearch/config/*; do ln -s ${file} ${ES_PATH_CONF}/${file##*/}; done;
find ${ES_PATH_CONF}/;

/usr/share/elasticsearch/bin/elasticsearch