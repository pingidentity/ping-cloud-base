#!/usr/bin/env sh

source /scripts/logger.sh

. "/scripts/wait-for.sh"

logger "INFO" "Copying mounted configmaps data into correspond folders started."

cp /enrichment-cache/* /enrichment-shared-volume/enrichment-cache/
cp /enrichment-logstash-search-templates/* /enrichment-shared-volume/logstash-search-templates/
cp /enrichment-elasticsearch-ilm-policies/* /enrichment-shared-volume/elasticsearch-ilm-policies/
cp /enrichment-elasticsearch-index-bootstraps/* /enrichment-shared-volume/elasticsearch-index-bootstraps/
cp /enrichment-elasticsearch-index-templates/* /enrichment-shared-volume/elasticsearch-index-templates/
cp /enrichment-elasticsearch-role-bootstraps/* /enrichment-shared-volume/elasticsearch-role-bootstraps/
cp /enrichment-kibana-config/* /enrichment-shared-volume/kibana-config/
cp /enrichment-logstash-config/* /enrichment-shared-volume/logstash-config/
cp /enrichment-certs-config/* /enrichment-shared-volume/certs-config/

# HERE SHOULD BE A COPIED FILES CHECK

logger "INFO" "Files was copied successfully."

# This installs required dependencies into the configure-es container. 
# These are REQUIRED for the enrichment script to work.

logger "INFO" "Dependencies installation started."

yum install -y epel-release
yum install -y python-pip
pip install requests

logger "INFO" "Dependencies installation done."

logger "INFO" "Starting enrichment script running..."
python /scripts/enrichment.py

. "/scripts/done.sh"