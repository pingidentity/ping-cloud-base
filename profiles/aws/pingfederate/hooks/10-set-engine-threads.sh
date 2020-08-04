#!/usr/bin/env sh
#
# This hook uses metadata provided via the downwardsAPI to calculate an approptiate
# number of threads for PingFederate to used based on the allocated CPU count.
#
${VERBOSE} && set -x
. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"
wd=$(pwd)
cd /opt/out/instance/etc
mv  jetty-runtime.xml jetty-runtime.xml.subst
CPUMIN=$(cat /etc/podinfo/cpu_request)
CPUMAX=$(cat /etc/podinfo/cpu_limit)
beluga_log "Processor Allocation: Requested: ${CPUMIN}m Limit: ${CPUMAX}m"
export THREADMIN=$(echo " 12 * ${CPUMIN} / 1000"|bc)
export THREADMAX=$(echo " 25 * ${CPUMAX} / 1000"|bc)
beluga_log "Jetty Runtime Thread Allocation: Min: ${THREADMIN} Max: ${THREADMAX}"
envsubst < jetty-runtime.xml.subst > jetty-runtime.xml
cd "${wd}"
exit 0
