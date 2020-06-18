#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Creating symbolic links referred to Elasticsearch config...";

for file in /usr/share/elasticsearch/config/*; do ln -s ${file} ${ES_PATH_CONF}/${file##*/}; done; #2> /dev/null; done;

if [[ -n "$(ls -la ${ES_PATH_CONF} | grep "\->")" ]]; then
    logger "INFO" "Symbolic links successfully created.";
else
    logger "ERROR" "Symbolic links wasn't created.";
fi

chown -R 1000:1000 /enrichment-shared-volume;
chown -R 1000:1000 //usr/share/elasticsearch/data;

. "/scripts/done.sh"