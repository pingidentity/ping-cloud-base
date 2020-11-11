#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

"${VERBOSE}" && set -x

if test ! "${OPERATIONAL_MODE}" = "CLUSTERED_ENGINE"; then
  echo "pre-stop: skipping pre-stop on admin"
  exit
fi

echo "pre-stop: starting pre-stop hook on engine"

# Retrieve Engine ID for engine name.
echo "pre-stop: removing engine ID for name ${ENGINE_NAME}"
ENGINES=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/engines")
test $? -ne 0 && exit 1

ENGINE_ID=$(jq -n "${ENGINES}" | jq --arg ENGINE_NAME "${ENGINE_NAME}" '.items[] | select(.name==$ENGINE_NAME) | .id')

if test -z "${ENGINE_ID}"; then
  echo "pre-stop: no engine ID found for name ${ENGINE_NAME}"
else
  echo "pre-stop: removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}"
  make_api_request -X DELETE "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/${ENGINE_ID}"
  test $? -ne 0 && exit 1

  echo "pre-stop: status of removing engine ID ${ENGINE_ID} for engine ${ENGINE_NAME}: ${?}"
fi

echo "pre-stop: finished pre-stop hook"