#!/bin/bash -e

# This script copies the kustomization templates into a temporary directory, performs substitution into them using
# environment variables defined in an env_vars file and builds the uber deploy.yaml file. It is run by the CD tool on
# every poll interval.

# Developing this script? Check out https://confluence.pingidentity.com/x/2StOCw
LOG_FILE=/tmp/git-ops-command.log

########################################################################################################################
# Add the provided message to LOG_FILE.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
log() {
  msg="$1"
  if [[ "${DEBUG}" == "true" ]]; then
    echo "git-ops-command: ${msg}"
  else
    echo "git-ops-command: ${msg}" >> "${LOG_FILE}"
  fi
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
  subst_dir="$2"

  log "substituting variables in '${env_file}' in directory ${subst_dir}"

  # Create a list of variables to substitute
  vars="$(grep -Ev "^$|#" "${env_file}" | cut -d= -f1 | awk '{ print "${" $1 "}" }')"
  log "substituting variables '${vars}'"

  # Export the environment variables
  set -a; . "${env_file}"; set +a

  for file in $(find "${subst_dir}" -type f); do
    old_file="${file}.bak"
    cp "${file}" "${old_file}"

    envsubst "${vars}" < "${old_file}" > "${file}"
    rm -f "${old_file}"
  done
}

########################################################################################################################
# Returns the first directory relative to the second.
#
# Arguments
#   $1 -> The directory to transform into a relative path.
#   $2 -> The directory relative to which the first directory must be transformed.
########################################################################################################################
relative_path() {
  to_transform="$(cd "${1%%/}"; pwd)"
  relative_to="$(cd "$2"; pwd)"

  # Move up from the directory to transform while counting the number of directories traversed until the other
  # directory is reached.
  dot_dots=
  while test "${relative_to#${to_transform}/}" = "${relative_to}"; do
    to_transform="$(dirname "${to_transform}")"
    dot_dots="../${dot_dots}"
  done

  echo ${dot_dots}${relative_to#${to_transform}/}
}

########################################################################################################################
# Comments out feature flagged resources from k8s-configs kustomization.yaml files.
#
# Arguments
#   $1 -> The directory containing k8s-configs.
########################################################################################################################
feature_flags() {
  cd "${1}/k8s-configs"

  # Map with the feature flag environment variable & the term to search to find the kustomization files
  flag_map="${RADIUS_PROXY_ENABLED}:ff-radius-proxy"

  for flag in $flag_map; do
    enabled="${flag%%:*}"
    search_term="${flag##*:}"
    log "${search_term} is set to ${enabled}"

    # If the feature flag is disabled, comment the search term lines out of the kustomization files
    if [[ ${enabled} != "true" ]]; then
      for kust_file in $(git grep -l "${search_term}" | grep "kustomization.yaml"); do
        log "Commenting out ${search_term} in ${kust_file}"
        sed -i.bak \
          -e "/${search_term}/ s|^#*|#|g" \
          "${kust_file}"
        rm -f "${kust_file}".bak
      done
    fi
  done
}
########################################################################################################################
# Comments the remove external ingress patch for ping apps from k8s-configs kustomization.yaml files.
# Hence the apps which are part of list in EXTERNAL_INGRESS_ENABLED will have external ingress enabled.
########################################################################################################################
enable_external_ingress() {
  cd "${TMP_DIR}"
  for apps in ${EXTERNAL_INGRESS_ENABLED}; do
    search_term="${apps}[/].*remove-external-ingress"
    for kust_file in $(grep --exclude-dir=.git -rwl -e "${search_term}" | grep "kustomization.yaml"); do
      log "Commenting external ingress for ${apps} in ${kust_file}"
      sed -i.bak \
        -e "/${search_term}/ s|^#*|#|g" \
        "${kust_file}"
      rm -f "${kust_file}".bak
    done
  done
}

########################################################################################################################
# Disable grafana operator CRDs if not argo environment.
########################################################################################################################
disable_grafana_crds() {
  cd "${TMP_DIR}"
  search_term="grafana-operator\/base"
  for kust_file in $(grep --exclude-dir=.git -rwl -e "${search_term}" | grep "kustomization.yaml"); do
      log "Commenting grafana ${kust_file}"
      sed -i.bak \
        -e "/${search_term}/ s|^#*|#|g" \
        "${kust_file}"
      rm -f "${kust_file}".bak
    done
}

########################################################################################################################
# Format the provided kustomize version for numeric comparison. For example, if the kustomize version is 4.0.5, it
# returns 004000005000.
#
# Arguments
#   ${1} -> The kustomize short version, e.g. v4.0.5.
########################################################################################################################
format_version() {
  version="$1"
  printf "%03d%03d%03d%03d" $(echo "${version}" | tr '.' ' ')
}

########################################################################################################################
# Returns the version of kustomize formatted for numeric comparison. For example, if the kustomize version is 4.0.5,
# it returns 004000005000.
########################################################################################################################
kustomize_version() {
  version="$(kustomize version --short | grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+')"
  format_version "${version}"
}

########################################################################################################################
# Clean up on exit. If non-zero exit, then print the log file to stdout before deleting it. Change back to the previous
# directory. Delete the kustomize build directory, if it exists.
########################################################################################################################
cleanup() {
  test $? -ne 0 && cat "${LOG_FILE}"
  rm -f "${LOG_FILE}"
  cd - >/dev/null 2>&1
  test ! -z "${TMP_DIR}" && rm -rf "${TMP_DIR}"
}

########################################################################################################################
# Terminates script on SIGTERM signal. Kustomize tends to hang, so needed to explicitly kill it if it exists.
########################################################################################################################
on_terminate() {
  log "Terminating on SIGTERM command"
  # kill kustomize command as it tends to hang
  kill -9 $kustomize_pid
  # kill rest of current script
  exit 0
}

# Main script

trap on_terminate SIGTERM

TARGET_DIR="${1:-.}"
cd "${TARGET_DIR}" >/dev/null 2>&1

if [[ "${DEBUG}" != "true" ]]; then
  # Trap all exit codes from here on so cleanup is run
  trap "cleanup" EXIT
fi

# Get short and full directory names of the target directory
TARGET_DIR_FULL="$(pwd)"
TARGET_DIR_SHORT="$(basename "${TARGET_DIR_FULL}")"

# Directory paths relative to TARGET_DIR
BASE_DIR='../base'

# Perform substitution and build in a temporary directory
if [[ ${DEBUG} == "true" ]]; then
  TMP_DIR="/tmp/git-ops-scratch-space"
  rm -rf "${TMP_DIR}"
  mkdir -p "${TMP_DIR}"
else
  TMP_DIR="$(mktemp -d)"
fi
BUILD_DIR="${TMP_DIR}/${TARGET_DIR_SHORT}"

# Copy contents of target directory into temporary directory
log "copying '${TARGET_DIR_FULL}' templates into '${TMP_DIR}'"
cp -pr "${TARGET_DIR_FULL}" "${TMP_DIR}"

if test -d "${BASE_DIR}"; then
  log "copying '${BASE_DIR}' templates into '${TMP_DIR}'" && \
  cp -pr "${BASE_DIR}" "${TMP_DIR}"
fi

# If there's an environment file, then perform substitution
if test -f 'env_vars'; then
  # Perform the substitutions in a sub-shell so it doesn't pollute the current shell.
  log "substituting env_vars into templates"
  (
    cd "${BUILD_DIR}"

    BASE_ENV_VARS="${BASE_DIR}"/env_vars
    env_vars_file=env_vars

    if test -f "${BASE_ENV_VARS}"; then
      env_vars_file="$(mktemp)"
      awk 1 env_vars "${BASE_ENV_VARS}" > "${env_vars_file}"
      substitute_vars "${env_vars_file}" "${BASE_DIR}"
    fi

    substitute_vars "${env_vars_file}" .

    PCB_TMP="${TMP_DIR}/${K8S_GIT_BRANCH}"

    # Try to copy a local repo to improve testing flow
    if [[ "${LOCAL}" == "true" ]]; then
      if [[ -z "${PCB_PATH}" ]]; then
        log "ERROR: running in local mode, please provide a PCB_PATH. Exiting."
        exit 1
      fi
      log "using PCB set by PCB_PATH: ${PCB_PATH}"
      cp -pr "${PCB_PATH}" "${PCB_TMP}"
    # Clone git branch from the upstream repo
    else
      log "cloning git branch '${K8S_GIT_BRANCH}' from: ${K8S_GIT_URL}"
      git clone -c advice.detachedHead=false -q --depth=1 -b "${K8S_GIT_BRANCH}" --single-branch "${K8S_GIT_URL}" "${PCB_TMP}"
    fi

    log "replacing remote repo URL '${K8S_GIT_URL}' with locally cloned repo at ${PCB_TMP}"
    kust_files="$(find "${TMP_DIR}" -name kustomization.yaml | grep -wv "${K8S_GIT_BRANCH}")"

    for kust_file in ${kust_files}; do
      rel_resource_dir="$(relative_path "$(dirname "${kust_file}")" "${PCB_TMP}")"
      log "replacing ${K8S_GIT_URL} in file ${kust_file} with ${rel_resource_dir}"
      sed -i.bak \
          -e "s|${K8S_GIT_URL}|${rel_resource_dir}|g" \
          -e "s|\?ref=${K8S_GIT_BRANCH}$||g" \
          "${kust_file}"
      rm -f "${kust_file}".bak
    done

    feature_flags "${TMP_DIR}/${K8S_GIT_BRANCH}"
    enable_external_ingress
  )
  test $? -ne 0 && exit 1
fi

KUST_VER="$(kustomize_version)"
log "detected kustomize version ${KUST_VER}"

# The load restriction build arg name and value are different starting in kustomize v4.0.1. This argument allows
# kustomize to load patch files that are not directly under the kustomize root. For example, we need this option for
# the remove-from-secondary-patch.yaml because it lives in base and is outside of the kustomize root of the region
# directories.
VER_4_0_1="$(format_version '4.0.1')"

if test ${KUST_VER} -ge ${VER_4_0_1}; then
  build_load_arg='--load-restrictor'
  build_load_arg_value='LoadRestrictionsNone'
else
  build_load_arg='--load_restrictor'
  build_load_arg_value='none'
fi

if ! command -v argocd &> /dev/null ; then
  disable_grafana_crds
fi

# Build the uber deploy yaml
if [[ ${DEBUG} == "true" ]]; then
  log "DEBUG - generating uber yaml file from '${BUILD_DIR}' to /tmp/uber-debug.yaml"
  kustomize build ${build_load_arg} ${build_load_arg_value} "${BUILD_DIR}" --output /tmp/uber-debug.yaml
# Output the yaml to stdout for Argo when operating normally
elif test -z "${OUT_DIR}" || test ! -d "${OUT_DIR}"; then
  log "generating uber yaml file from '${BUILD_DIR}' to stdout"
  kustomize build ${build_load_arg} ${build_load_arg_value} "${BUILD_DIR}" &
  kustomize_pid=$!
  wait
# TODO: leave this functionality for now - it outputs many yaml files to the OUT_DIR
# it isn't clear if this is still used in actual CDEs
else
  log "generating yaml files from '${BUILD_DIR}' to '${OUT_DIR}'"
  kustomize build ${build_load_arg} ${build_load_arg_value} "${BUILD_DIR}" --output "${OUT_DIR}"
fi

exit 0
