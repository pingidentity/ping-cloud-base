#!/usr/bin/env sh

source /scripts/logger.sh

export ELASTICSEARCH_USERNAME=kibana_system
export ELASTICSEARCH_PASSWORD=`cat /enrichment-shared-volume/passwords/kibana`

/usr/share/kibana/bin/kibana

. "/scripts/done.sh"