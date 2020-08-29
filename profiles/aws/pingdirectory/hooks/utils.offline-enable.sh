# Functions

. "${HOOKS_DIR}/utils.lib.sh"

# Escape base DNs so that they can appear in LDIF.
function escape_dn() {
  local dn="$1"
  echo "${dn}" | tr ',=' "__"
}

# Escape strings so that they can appear in grep.
function escape_regex() {
  local str="$1"
  echo "${str}" | sed 's/\([.^$]\)/\\\1/g'
}

# Verify that each required parameter was provided to offline-enable script. Return with status code 1 if not provided.
function verifyParams() {
  # The configuration parameters passed to this script via a JSON configuration file.
  params="descriptor_json \
    inst_root \
    hostname_prefix \
    local_tenant_domain \
    local_region \
    local_num_replicas \
    local_ordinal \
    repl_id_base \
    repl_id_rinc \
    repl_id_inc \
    https_port_base \
    ldap_port_base \
    ldaps_port_base \
    repl_port_base \
    port_inc \
    ads_crt_file \
    admin_user \
    admin_pass_file"

  for param in ${params}; do
    local value=$(jq -r ".${param}" "${config_json}")
    if [ -z "${value}" ] || [ "${value}" = 'null' ]; then
      beluga_log "Parameter '${param}' is missing from configuration file '${config_json}'"
      return 1
    fi
    eval $param=\"\${value}\"
  done
}

# Validate descriptor.json has proper JSON syntax. Return with status code 1 if the JSON cannot be parsed.
function validateDescriptorJsonSyntax() {
  beluga_log "Validate the descriptor.json syntax"

  # Verify file isn't empty
  ! test -s "${descriptor_json}" && beluga_log "descriptor.json is empty" && return 1

  # Verify JSON is parsable
  local json_str=$( cat "${descriptor_json}" )
  test $(jq -n "${json_str}" > /dev/null 2>&1; echo $?) != "0" && beluga_log "Invalid JSON descriptor file" && return 1
  return 0
}

# Get the region(s) from JSON descriptor, and write it to regions.txt.
# Verify that each region has a region name without spaces and is unique. 
# Also, verify hostname and replica count are included per region. Return with status code 1 if fail.
function verifyDescriptorJsonSchema() {

  beluga_log "Verifying descriptor.json content"
  cat "${descriptor_json}"

  # Verify no duplicate keys. Use jq to filter out duplicate keys and compare against descriptor.json.
  jq -r '.' "${descriptor_json}"  > "${regions_file}"
  diff -w "${descriptor_json}" "${regions_file}" > /dev/null
  test $? -ne 0 && beluga_log "descriptor.json contains duplicate keys" && return 1

  # Verify there is at least 1 region name within descriptor.json file
  test $(jq -r '(keys_unsorted|length)' "${descriptor_json}") -lt 1 && beluga_log "No regions found within \
    descriptor file: ${descriptor_json}" && return 1

  jq -r 'keys_unsorted | .[]' "${descriptor_json}" > "${regions_file}"

  # Verify spaces are not included in region names
  test $( grep -q ' ' "${regions_file}" ) && beluga_log "There is at least 1 region name that contains \
    a space within descriptor file: ${descriptor_json}" && return 1

  for region in $(cat "${regions_file}"); do

    # Verify hostname is included
    local hostname=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")
    (test $? -ne 0 || test -z "${hostname}") && beluga_log "Empty hostname within descriptor file: ${descriptor_json}" && return 1

    # Verify replica count is included and is a number
    local count=$(jq -r ".[\"${region}\"].replicas" "${descriptor_json}")
    (test $? -ne 0 || test -z "${count}") && beluga_log "Empty replica count within descriptor file: ${descriptor_json}" && return 1

    echo "${count}" | egrep -iq '^[0-9]'
    test $? -ne 0 && 
      beluga_log "Invalid replica count within descriptor file: ${descriptor_json}. Replica count, ${count}, must \
        match the regex: /^[0-9]/" && return 1
  done

  return 0
}

# Set the local region, hostname, and replica count. Return with status code 1 if local hostname 
# or replica count isn't the same as k8s Statefulset.
function setLocalRegion() {
  for region in $(cat "${regions_file}"); do
    hostname_from_desc_file=$(jq -r ".[\"${region}\"].hostname" "${descriptor_json}")
    if test "${region}" = "${local_region}" ||
      $(echo "${hostname_from_desc_file}" | grep -qi "${local_tenant_domain}"); then
      local_region="${region}"
      local_hostname="${hostname_from_desc_file}"
      local_count=$(jq -r ".[\"${local_region}\"].replicas" "${descriptor_json}")
      break
    fi
  done

  if [ -z "${local_hostname}" ]; then
    beluga_log "Hostname for local cluster does not exist in the topology descriptor file"
    return 1
  fi

  if [ "${local_num_replicas}" -ne "${local_count}" ]; then
    beluga_log "Mismatch in replicas for ${region} - expected: ${local_num_replicas}, actual: ${local_count}"
    return 1
  fi

  # Determine the number of local replicas
  beluga_log "local_region: ${local_region}"
  beluga_log "local_hostname: ${local_hostname}"
  beluga_log "local_count: ${local_count}"
}