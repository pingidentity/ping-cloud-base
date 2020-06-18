#!/usr/bin/env sh

source /scripts/logger.sh

logger "INFO" "Creating enrichment volume folders..."

dirs_path=/enrichment-shared-volume

set -- "logs" "enrichment-cache" "certs" "secrets"
while [ $# -gt 0 ]
do        
    mkdir -p $dirs_path/$1
    if [ -d "$dirs_path/$1" ]; then
        logger "INFO" "Folder $dirs_path/$1 exist."
    else
        logger "ERROR" "Folder $dirs_path/$1 not exist."
    fi
    shift;
done

chown -R 1000:1000 /enrichment-shared-volume

. "/scripts/done.sh"