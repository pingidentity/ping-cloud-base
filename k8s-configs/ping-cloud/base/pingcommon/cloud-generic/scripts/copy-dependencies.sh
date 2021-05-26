#!/bin/sh

. "./utils.lib.sh"

beluga_log "Copying SSH configuration files"
test -f /known_hosts && cp /known_hosts /.ssh
test -f /id_rsa && cp /id_rsa /.ssh

beluga_log "Copying kubectl to the data directory"
which kubectl | xargs -I {} cp {} /data

beluga_log "Checking kubectl executable in data directory"
if test ! -f /data/kubectl; then
    beluga_log "Failed to locate /data/kubectl" "ERROR"
    exit 1
fi

beluga_log "Downloading skbn from ping-artifacts bucket"
wget -qO /data/skbn https://ping-artifacts.s3-us-west-2.amazonaws.com/pingcommon/skbn/0.5.1/skbn

beluga_log "Checking skbn executable in data directory"
if test ! -f /data/skbn; then
    beluga_log "Failed to locate /data/skbn" "ERROR"
    exit 1
fi

beluga_log "Updating skbn permission"
chmod +x /data/skbn

beluga_log "Generate a dummy topology JSON file so the hook that generates it in the image is not triggered"

TOPOLOGY_FILE=/data/topology.json
cat <<EOF > "${TOPOLOGY_FILE}"
{
        "serverInstances" : []
}
EOF

beluga_log 'Downloading custom native S3 ping jar from ping-artifacts bucket'

DST_FILE='/data/native-s3-ping.jar'
wget -qO "${DST_FILE}" \
    https://ping-artifacts.s3-us-west-2.amazonaws.com/pingfederate/native-s3-ping/0.9.5.Final/native-s3-ping.jar

beluga_log 'Checking for native-s3-ping.jar in data directory'
if test ! -f "${DST_FILE}"; then
    beluga_log "Failed to locate '${DST_FILE}'" 'ERROR'
    exit 1
fi

beluga_log 'Downloading JMX prometheus Java Agent from ping-artifacts bucket'

DST_FILE='/data/jmx_prometheus_javaagent-0.14.0.jar'
wget -qO "${DST_FILE}" \
    https://ping-artifacts.s3-us-west-2.amazonaws.com/pingcommon/jmx-prometheus-javaagent/0.14.0/jmx_prometheus_javaagent-0.14.0.jar

beluga_log 'Checking for jmx_prometheus_javaagent jar file in data directory'
if test ! -f "${DST_FILE}"; then
    beluga_log "Failed to locate '${DST_FILE}'" 'ERROR'
    exit 1
fi

beluga_log 'Downloading NewRelic Java APM Agent from ping-artifacts bucket'

DST_FILE='/data/newrelic.jar'
wget -qO "${DST_FILE}" \
    https://ping-artifacts.s3.amazonaws.com/pingcommon/newrelic-java-agent/6.4.2/newrelic.jar

beluga_log 'Checking for newrelic jar file in data directory'
if test ! -f "${DST_FILE}"; then
    beluga_log "Failed to locate '${DST_FILE}'" 'ERROR'
    exit 1
fi
beluga_log "Execution completed successfully"

exit 0
