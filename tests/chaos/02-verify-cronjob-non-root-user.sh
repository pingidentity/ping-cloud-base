#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

# Verify ping user is set in k8s config file
testNonRootCronjob() {
  cronjobs=$(kubectl get cronjob \
    -n "${PING_CLOUD_NAMESPACE}" \
    -o json | jq -c '.items[].spec.jobTemplate.spec.template.spec.containers[]')
  echo "Looping through cronjobs to test"
  echo "${cronjobs}" | while read -r cronjob
  do
    cronjob_name=$(echo "${cronjob}" | jq '.name')
    runAsNonRoot=$(echo "${cronjob}" | jq '.securityContext.runAsNonRoot')
    runAsUser=$(echo "${cronjob}" | jq '.securityContext.runAsUser')

    assertEquals "Cronjob: ${cronjob_name}: Failed to get securityContext: runAsNonRoot" "${runAsNonRoot}" "true"
    # 9031 is the 'ping' user
    assertEquals "Cronjob: ${cronjob_name}: Failed to get securityContext: runAsUser" "${runAsUser}" "9031"
  done
}

testNonRootCronjobUserId() {
  cronjobs=$(kubectl get cronjob --no-headers -o custom-columns=":metadata.name")
  for cronjob in ${cronjobs}; do
    # Run pod long enough to be able to exec into pod and run whoami to verify user
    job="${cronjob}-uid"
    kubectl create job \
      ${job} \
      -n ${PING_CLOUD_NAMESPACE} \
      --from=cronjob/${cronjob} \
      --dry-run=client \
      -o json > cronjob.json

    # update command to sleep 45 when job runs
    echo $(cat cronjob.json | jq '.spec.template.spec.containers[].command |= ["sh","-c","sleep 45s"]') \
      > cronjob.json

    kubectl apply -f cronjob.json

    pod=$(kubectl get po -l job-name=${job} -o name)
    kubectl wait --for=condition=Ready ${pod}

    user=$(kubectl exec job/${job} -- whoami)
    assertEquals "Cronjob: ${cronjob} - user not found" "ping" "${user}"

    # remove test job
    kubectl delete job ${job}
    rm -f cronjob.json
  done
}

# When arguments are passed to a script you must
# consume all of them before shunit is invoked
# or your script won't run. For integration
# tests, you need this line
shift $#

# load shunit
. ${SHUNIT_PATH}