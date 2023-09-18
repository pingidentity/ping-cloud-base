#!/bin/sh

. "./utils.lib.sh"

NEWRELIC_VERSION="8.6.0"

beluga_log "Copying logger.lib.sh"
test -f ./logger.lib.sh && cp ./logger.lib.sh /data/logger.lib.sh

beluga_log "Copying SSH configuration files"
test -f /known_hosts && cp /known_hosts /.ssh
test -f /id_rsa && cp /id_rsa /.ssh

beluga_log "Updating id_rsa permission"
chmod 400 /.ssh/id_rsa

beluga_log "Copying kubectl to the data directory"
which kubectl | xargs -I {} cp {} /data

beluga_log "Checking kubectl executable in data directory"
if test ! -f /data/kubectl; then
    beluga_log "Failed to locate /data/kubectl" "ERROR"
    exit 1
fi

beluga_log "Generate a dummy topology JSON file so the hook that generates it in the image is not triggered"

TOPOLOGY_FILE=/data/topology.json
cat <<EOF > "${TOPOLOGY_FILE}"
{
        "serverInstances" : []
}
EOF

beluga_log 'Downloading JMX prometheus Java Agent from ping-artifacts bucket'

DST_FILE='/data/jmx_prometheus_javaagent-0.14.0.jar'
wget -qO "${DST_FILE}" \
    https://ping-artifacts.s3-us-west-2.amazonaws.com/pingcommon/jmx-prometheus-javaagent/0.14.0/jmx_prometheus_javaagent-0.14.0.jar

beluga_log 'Checking for jmx_prometheus_javaagent jar file in data directory'
if test ! -s "${DST_FILE}"; then
    beluga_log "Failed to locate '${DST_FILE}'" 'ERROR'
    exit 1
fi

beluga_log "Downloading NewRelic Java APM Agent version ${NEWRELIC_VERSION} from ping-artifacts bucket"

DST_FILE='/data/newrelic.jar'
wget -qO "${DST_FILE}" \
    "https://ping-artifacts.s3.amazonaws.com/pingcommon/newrelic-java-agent/${NEWRELIC_VERSION}/newrelic.jar"

beluga_log 'Checking for newrelic jar file in data directory'
if test ! -s "${DST_FILE}"; then
    beluga_log "Failed to locate '${DST_FILE}'" 'ERROR'
    exit 1
fi
beluga_log "Execution completed successfully"

exit 0
