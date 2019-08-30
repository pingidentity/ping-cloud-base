#!/bin/sh
set -ex

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

isReady() {
  STATUS=$(kubectl get pods -n ping-cloud --no-headers | awk '{ print $2; }')

  NUM_PODS=$(echo ${STATUS} | wc | awk '{ print $2; }')
  log "number of pods: ${NUM_PODS}"

  NUM_READY=$(echo ${STATUS} | grep -o '1/1' | wc -l | awk '{ print $1; }')
  log "number ready: ${NUM_READY}"

  if [[ ${NUM_READY} -eq ${NUM_PODS} ]]; then
    return 0
  else
    return 1
  fi
}

# Check if all pods are ready 60 times with an initial timeout of 2 seconds
retryWithBackoff 60 2 isReady