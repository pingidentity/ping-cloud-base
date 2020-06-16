#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

if [[ ! -z "${ES_PATH_CONF}/elasticsearch.keystore" ]]; then
    /usr/share/elasticsearch/bin/elasticsearch & sleep 60 && /usr/share/elasticsearch/bin/elasticsearch-keystore create;
    /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto -v > /usr/share/elasticsearch/data/elasticsearch-setup-passwords.log;
    export ELASTIC_TEMP_PASSWORD=`cat /usr/share/elasticsearch/data/elasticsearch-setup-passwords.log | grep "PASSWORD elastic" | cut -d " " -f 4`;
    rm /usr/share/elasticsearch/data/elasticsearch-setup-passwords.log;
fi;

curl --header "Content-Type: application/json" --request POST --data '{"password":"'"$ELASTIC_PASSWORD"'"}' \https://127.0.0.1:9200/_security/user/elastic/_password --key /enrichment-shared-volume/certificates/es-cluster-0/es-cluster-0.key --cert /enrichment-shared-volume/certificates/es-cluster-0/es-cluster-0.crt --cacert /enrichment-shared-volume/certificates/ca/ca.crt -u elastic:${ELASTIC_TEMP_PASSWORD} -k -v;

curl https://127.0.0.1:9200/_cluster/health --key /enrichment-shared-volume/certificates/es-cluster-0/es-cluster-0.key --cert /enrichment-shared-volume/certificates/es-cluster-0/es-cluster-0.crt --cacert /enrichment-shared-volume/certificates/ca/ca.crt -u elastic:passwd -k -v;

echo $ELASTIC_PASSWORD > /enrichment-shared-volume/passwords/elasticsearch

chown -R 1000:1000 /enrichment-shared-volume

sleep 999999999999;

. "/scripts/done.sh"