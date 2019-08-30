#!/bin/bash
set -e

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
. ${SCRIPT_HOME}/../common.sh

function isReady() {
  STATUS=$(kubectl get pods -n ping-cloud --no-headers | awk '{ print $2; }')

  NUM_PODS=$(echo ${STATUS} | wc | awk '{ print $2; }')
  log "number of pods: ${NUM_PODS}"

  NUM_READY=$(echo ${STATUS} | grep -o '1/1' | wc -l | awk '{ print $1; }')
  log "number ready: ${NUM_READY}"

  [[ ${NUM_READY} -eq ${NUM_PODS} ]] && return 0 || return 1
}

# Check if all pods are ready 60 times with an initial timeout of 2 seconds
retryWithBackoff 60 2 isReady