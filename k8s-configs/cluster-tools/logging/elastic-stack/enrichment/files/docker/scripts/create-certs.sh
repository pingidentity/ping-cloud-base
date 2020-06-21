#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/create-symlinks.sh"

chown -R 1000:1000 /enrichment-shared-volume;
chown -R 1000:1000 /usr/share/elasticsearch/data;

# HERE SHOULD BE SSL CERTIFICATIONS CREATION

logger "INFO" "$CONTAINER_NAME: Job done!"