#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

if [[ ! -f /enrichment-shared-volume/certs/bundle.zip ]]; then
    /usr/share/elasticsearch/bin/elasticsearch-certutil cert --silent --pem --in /enrichment-shared-volume/certs-config/instances.yml -out /enrichment-shared-volume/certs/bundle.zip;
fi;

yum install -y unzip

unzip -o /enrichment-shared-volume/certs/bundle.zip -d /enrichment-shared-volume/certs

# chown -R 1000:0 /enrichment-shared-volume/certs

. "/scripts/done.sh"