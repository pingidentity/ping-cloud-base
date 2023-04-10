#!/bin/bash

CI_SCRIPTS_DIR="${SHARED_CI_SCRIPTS_DIR:-/ci-scripts}"
. "${CI_SCRIPTS_DIR}"/common.sh "${1}"

if skipTest "${0}"; then
  log "Skipping test ${0}"
  exit 0
fi

log "Query endpoint: ${PINGCLOUD_METADATA_API}"
RETURN_VAL=$(curl -s -m 5 -k -L "${PINGCLOUD_METADATA_API}")
if [ $? -ne 0 ]; then 
  log "Failed to connect to: ${PINGCLOUD_METADATA_API}"
  exit 1
fi

log "Verifying that the response is valid json"
if ! jq -e . >/dev/null 2>&1 <<< "${RETURN_VAL}"; then
  echo "Invalid json response: ${RETURN_VAL}"
  exit 1
fi

log "Verifying image ids retrieved from the metadata endpoint"
temp_file_metadata="$(mktemp)"
temp_file_kubectl="$(mktemp)"

echo "${RETURN_VAL}" | jq -r '.[] [].image' | grep -v 'N/A' > "${temp_file_metadata}"

for image_id in $(kubectl -n "${PING_CLOUD_NAMESPACE}" get pod -o jsonpath="{.items[*].spec.containers[*].image}");
do
  echo "${image_id}" >> "${temp_file_kubectl}";
done

UNMATCHED_ID=$(comm -23 <(sort "${temp_file_metadata}") <(sort "${temp_file_kubectl}"))

if ! test -z "${UNMATCHED_ID}"; then
  log "The following image id does not exists: ${UNMATCHED_ID}"
  exit 1
fi

exit 0
