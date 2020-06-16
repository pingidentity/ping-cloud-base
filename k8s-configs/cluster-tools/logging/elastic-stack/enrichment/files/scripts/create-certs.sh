#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

logger "INFO" "Creating symlinks to Elasticsearch config files on shared volume";
ln -s /enrichment-shared-volume/certs ${ES_PATH_CONF}/certs 2> /dev/null;
# for file in /enrichment-shared-volume/elasticsearch/*; do ln -s ${file} ${ES_PATH_CONF}/${file##*/} 2> /dev/null; done;
# find ${ES_PATH_CONF}/;
# rm ${ES_PATH_CONF}/bundle.zip;
[[ ! -f ${ES_PATH_CONF}/bundle.zip ]] && /usr/share/elasticsearch/bin/elasticsearch-certutil cert --silent --pem --in ${ES_PATH_CONF}/instances.yml -out ${ES_PATH_CONF}/bundle.zip;
unzip -o ${ES_PATH_CONF}/bundle.zip -d ${ES_PATH_CONF}/certs;
cp -r ${ES_PATH_CONF}/* /usr/share/elasticsearch/data/config/;
chown -R 1000:1000 /usr/share/elasticsearch/data;
chown -R 1000:1000 /enrichment-shared-volume;

. "/scripts/done.sh"