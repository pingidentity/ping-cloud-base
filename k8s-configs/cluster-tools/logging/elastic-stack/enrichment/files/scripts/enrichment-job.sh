#!/usr/bin/env sh

source /scripts/logger.sh

# This installs required dependencies into the configure-es container. 
# These are REQUIRED for the enrichment script to work.

logger "INFO" "Dependencies installation started."

yum install -y epel-release
yum install -y python-pip
pip install requests

logger "INFO" "Dependencies installation done."

logger "INFO" "Starting enrichment script running..."
python /scripts/enrichment.py

chown -R 1000:1000 /enrichment-shared-volume

. "/scripts/done.sh"