#!/usr/bin/env sh

logger()
{
    LOG_DIR_PATH=/enrichment-shared-volume/logs
    LOG_FILE=${CONTAINER_NAME}_$(date +'%d.%m.%Y').log

    mkdir -p $LOG_DIR_PATH && touch $LOG_DIR_PATH/$LOG_FILE

    echo -e "$1\t$(date +'%F %T')\t$CONTAINER_NAME\t$2" | tee -a $LOG_DIR_PATH/$LOG_FILE
}