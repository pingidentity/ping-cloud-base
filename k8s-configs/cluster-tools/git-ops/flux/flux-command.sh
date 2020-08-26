#!/bin/sh

set -e

LOG_FILE=/tmp/flux-command.log

########################################################################################################################
# Add the provided message to LOG_FILE.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
log() {
  msg="$1"
  echo "${msg}" >"${LOG_FILE}"
}

########################################################################################################################
# Substitute variables in all files in the provided directory with the values provided through the environments file.
#
# Arguments
#   $1 -> The file containing the environment variables to substitute.
#   $2 -> The directory that contains the files where variables must be substituted.
########################################################################################################################
substitute_vars() {
  env_file="$1"
  if test ! -f "${env_file}"; then
    log "flux-command: env_file '${env_file}' does not exist"
    return 1
  fi

  subst_dir="$2"
  if test ! -d "${subst_dir}"; then
    log "flux-command: subst_dir '${subst_dir}' does not exist"
    return 1
  fi

  log "flux-command: substituting variables in '${env_file}' in directory ${subst_dir}"

  # Create a list of variables to substitute
  vars="$(grep -Ev "^$|#" "${env_file}" | cut -d= -f1 | awk '{ print "\$\{" $1 "\}" }')"
  log "flux-command: substituting variables '${vars}'"

  # Export the environment variables
  set -a
  source "${env_file}"
  set +a

  for file in $(find "${subst_dir}" -type f); do
    old_file="${file}.bak"
    cp "${file}" "${old_file}"

    envsubst "${vars}" < "${old_file}" > "${file}"
    rm -f "${old_file}"
  done

  return 0
}

########################################################################################################################
# Change back to the previous directory on exit. If non-zero exit, then print the log file to stdout first.
########################################################################################################################
change_dir_to_previous() {
  test $? -ne 0 && cat "${LOG_FILE}"
  cd - >/dev/null 2>&1
}

# Main script
trap "change_dir_to_previous" EXIT

TARGET_DIR="${1:-.}"
TARGET_DIR_FULL="$(cd "${TARGET_DIR}"; pwd)"

cd "${TARGET_DIR_FULL}" >/dev/null 2>&1

TOOLS_DIR='cluster-tools'
PING_CLOUD_DIR='ping-cloud'
BASE_DIR='base'

if test ! -d "${TOOLS_DIR}" && test ! -d "${PING_CLOUD_DIR}"; then
  log "flux-command: expected directories ${TOOLS_DIR} and/or ${PING_CLOUD_DIR} not present under ${TARGET_DIR_FULL}"
  exit 1
fi

substitute_vars env_vars .
substitute_vars env_vars ../"${BASE_DIR}"

log "flux-command: running 'kustomize build' on '${TARGET_DIR_FULL}'"
kustomize build --load_restrictor LoadRestrictionsNone .

exit 0