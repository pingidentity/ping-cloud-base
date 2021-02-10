#!/usr/bin/env sh

get_admin_version() {
  # Establish running version of the admin server.
  version=$(make_api_request https://"${ADMIN_HOST_PORT}"/pa-admin-api/v3/version | jq -r .version)
  return_code=${?}

  echo "${version}"
  return ${return_code}
}

get_https_listeners() {
  https_listeners=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/httpsListeners")
  return_code=${?}

  echo "${https_listeners}"
  return ${return_code}
}

get_key_pair_id() {
  https_listeners="${1}"
  key_pair_id=$(jq -n "${https_listeners}" | jq '.items[] | select(.name=="CONFIG QUERY") | .keyPairId')
  return_code=${?}

  echo "$key_pair_id"
  return ${return_code}
}

get_key_pairs() {
  key_pairs=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/keyPairs")
  return_code=${?}

  echo "${key_pairs}"
  return ${return_code}
}

get_alias() {
  key_pairs="${1}"
  key_pair_id="${2}"
  alias=$(jq -n "${key_pairs}" | jq -r '.items[] | select(.id=='${key_pair_id}') | .alias')
  return_code=${?}

  echo "${alias}"
  return ${return_code}
}

get_engine_trusted_certs() {
  trusted_certs=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/engines/certificates")
  return_code=${?}

  echo "${trusted_certs}"
  return ${return_code}
}

get_engines() {
  engines=$(make_api_request "${PINGACCESS_ADMIN_API_ENDPOINT}/engines")
  return_code=${?}

  echo "${engines}"
  return ${return_code}
}

