#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Creating symbolic links referred to Elasticsearch config...";

for file in /usr/share/elasticsearch/config/*; do 
    ln -sf ${file} ${ES_PATH_CONF}/${file##*/}; 
done;

if [[ -n "$(ls -la ${ES_PATH_CONF} | grep "\->")" ]]; then
    logger "INFO" "Symbolic links successfully created.";
else
    logger "ERROR" "Symbolic links wasn't created.";
fi