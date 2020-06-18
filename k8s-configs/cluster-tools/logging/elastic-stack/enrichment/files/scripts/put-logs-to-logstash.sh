#!/usr/bin/env sh

source /scripts/logger.sh

logstash_status="bad"

logger "INFO" "Starting pushing logs to Logstash..."

# Parse Parameters
while getopts 'af' OPTION
do
  case ${OPTION} in
    a)
      logs_path='/enrichment-shared-volume/logs/*'
      ;;
    f)
      logs_path="/enrichment-shared-volume/logs/${CONTAINER_NAME}_`date +'%d.%m.%Y'`.log"
      ;;
    *)
      echo "Usage ${0} [ -a ] a = get all logs files, [ -f ] f = get current container log file"
      popd  > /dev/null 2>&1
      exit 1
      ;;
  esac
done

#Wait for Logstash API to go Green before sending logs
while [ "$logstash_status" != "ok" ]
do
  logger "INFO" "Logstash status not Green yet, waiting for Logtash become operational..."
  sleep 3
  logstash_status=$(curl -s --insecure $LOGSTASH_URL:$LOGSTASH_PORT/)
done

logger "INFO" "Starting to pushing logs into logstash..."

for file in $logs_path; do
    while IFS= read -r line
    do
        tmpline=$(sed -r "s/\t/#/g" <<< $line)
        IFS=$'#'
        tmp=($tmpline)
        event_type="${tmp[0]}"
        event_timestamp="${tmp[1]}"
        producer_name="${tmp[2]}"
        event_message="${tmp[3]}"
        curl -s -X POST $LOGSTASH_URL:$LOGSTASH_PORT --insecure \
            -H 'Content-Type: application/json' \
            -d '{"event_type":"'"$event_type"'", "event_timestamp":"'"$event_timestamp"'","producer_name":"'"$producer_name"'","event_message":"'"$event_message"'"}';
    done < "$file"
done;

rm $logs_path

logger "INFO" "Logs pushing completed."

. "/scripts/done.sh"