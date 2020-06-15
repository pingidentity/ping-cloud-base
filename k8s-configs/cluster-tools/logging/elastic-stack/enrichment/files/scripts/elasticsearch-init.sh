#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

cp /enrichment-shared-volume/certs/elasticsearch/* $ES_PATH_CONF/certificates/
cp /enrichment-shared-volume/certs/ca/* $ES_PATH_CONF/certificates/

find /usr/share/elasticsearch/config/ ! -name 'elasticsearch.yml' -exec cp {} $ES_PATH_CONF/ \;

if [[ ! -z "$ES_PATH_CONF/elasticsearch.keystore" ]]; then
    /usr/share/elasticsearch/bin/elasticsearch-keystore create &&
    # printf `echo $ELASTIC_PASSWORD | base64 -d` | /usr/share/elasticsearch/bin/elasticsearch-keystore add -x "boostrap.password"

    # printf $ELASTIC_PASSWORD | /usr/share/elasticsearch/bin/elasticsearch-keystore add -x "bootstrap.password"
    /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b -v
fi

chown -R 1000:1000 $ES_PATH_CONF

ls -l $ES_PATH_CONF

# /usr/share/elasticsearch/bin/elasticsearch-keystore create
# /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -b -v

. "/scripts/done.sh"