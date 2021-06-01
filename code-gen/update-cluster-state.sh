#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

# This script may be used to upgrade an existing cluster state repo. It is designed to be non-destructive in that it
# won't push any changes to the server. Instead, it will set up a parallel branch for every CDE branch corresponding to
# the environments specified through the ENVIRONMENTS environment variable. For example, if the new version is v1.7.1,
# then it’ll set up 4 new branches at the new version for the default set of environments: v1.7.1-dev, v1.7.1-test,
# v1.7.1-stage and v1.7.1-master.

# NOTE: The script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   NEW_VERSION -> Required. The new version of Beluga to which to update the cluster state repo.
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod', if unset. If provided,
#       it must contain all or a subset of the environments currently created by the generate-cluster-state.sh script,
#       i.e. dev, test, stage, prod.
#   RESET_TO_DEFAULT -> An optional flag, which if set to true will reset the cluster-state-repo to the OOTB state
#       for the new version. This has the same effect as running the platform code build job.

### Global values and utility functions ###
BASE64_DECODE_OPT="${BASE64_DECODE_OPT:--D}"

K8S_CONFIGS_DIR='k8s-configs'
PROFILES_DIR='profiles'
BASE_DIR='base'

CODE_GEN_DIR='code-gen'
TEMPLATES_DIR='templates'
TEMPLATES_BASE_DIR="${CODE_GEN_DIR}/${TEMPLATES_DIR}/${BASE_DIR}"
TEMPLATES_REGION_DIR="${CODE_GEN_DIR}/${TEMPLATES_DIR}/region"

CUSTOM_RESOURCES_DIR='custom-resources'
CUSTOM_PATCHES_FILE_NAME='custom-patches.yaml'
CUSTOM_PATCHES_SAMPLE_FILE_NAME='custom-patches-sample.yaml'
CUSTOM_RESOURCES_REL_DIR="${K8S_CONFIGS_DIR}/${BASE_DIR}/${CUSTOM_RESOURCES_DIR}"
CUSTOM_PATCHES_REL_FILE_NAME="${K8S_CONFIGS_DIR}/${BASE_DIR}/${CUSTOM_PATCHES_FILE_NAME}"

ARTIFACTS_JSON_FILE_NAME='artifact-list.json'

ENV_VARS_FILE_NAME='env_vars'
SECRETS_FILE_NAME='secrets.yaml'
ORIG_SECRETS_FILE_NAME='orig-secrets.yaml'
SEALED_SECRETS_FILE_NAME='sealed-secrets.yaml'

CLUSTER_STATE_REPO='cluster-state-repo'

PING_CLOUD_BASE='ping-cloud-base'
PING_CLOUD_DEFAULT_DEVOPS_USER='pingcloudpt-licensing@pingidentity.com'

# If true, reset to the OOTB cluster state for the new version, i.e. perform no migration.
RESET_TO_DEFAULT="${RESET_TO_DEFAULT:-false}"

# FIXME: obtain the list of known k8s files between the old and new versions dynamically

# List of k8s files not to copy over. These are OOTB k8s config files for a Beluga release and not customized by
# PS/GSO. The following list is union of all files under k8s-configs from v1.6 through v1.8 and obtained by running
# these commands:
#
#     find "${K8S_CONFIGS_DIR}" -type f -exec basename {} + | sort -u   # Run this command on each tag
#     cat v1.7-k8s-files v1.8-k8s-files | sort -u                       # Create a union of the k8s files

beluga_owned_k8s_files="@.flux.yaml \
@argo-application.yaml \
@custom-patches-sample.yaml \
@descriptor.json \
@env_vars \
@flux-command.sh \
@git-ops-command.sh \
@known-hosts-config.yaml \
@kustomization.yaml \
@orig-secrets.yaml \
@secrets.yaml \
@sealed-secrets.yaml \
@region-promotion.txt \
@remove-from-secondary-patch.yaml \
@seal.sh"

# The list of variables to substitute in env_vars.old files.
# shellcheck disable=SC2016
ENV_VARS_TO_SUBST='${IS_MULTI_CLUSTER}
${CLUSTER_BUCKET_NAME}
${SECONDARY_TENANT_DOMAINS}
${REGION}
${REGION_NICK_NAME}
${PRIMARY_REGION}
${TENANT_DOMAIN}
${TENANT_NAME}
${PRIMARY_TENANT_DOMAIN}
${GLOBAL_TENANT_DOMAIN}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
${LOG_ARCHIVE_URL}
${BACKUP_URL}
${PING_CLOUD_NAMESPACE}
${K8S_GIT_URL}
${K8S_GIT_BRANCH}
${JFROG_REGISTRY_NAME}
${ECR_REGISTRY_NAME}
${KNOWN_HOSTS_CLUSTER_STATE_REPO}
${CLUSTER_STATE_REPO_URL}
${CLUSTER_STATE_REPO_BRANCH}
${CLUSTER_STATE_REPO_PATH_DERIVED}
${SERVER_PROFILE_URL_DERIVED}
${SERVER_PROFILE_BRANCH_DERIVED}
${ENV}
${ENVIRONMENT_TYPE}
${KUSTOMIZE_BASE}
${LETS_ENCRYPT_SERVER}
${USER_BASE_DN}
${PF_PD_BIND_PORT}
${PF_PD_BIND_PROTOCOL}
${PF_PD_BIND_USESSL}
${PF_MIN_HEAP}
${PF_MAX_HEAP}
${PF_MIN_YGEN}
${PF_MAX_YGEN}
${PA_WAS_MIN_HEAP}
${PA_WAS_MAX_HEAP}
${PA_WAS_MIN_YGEN}
${PA_WAS_MAX_YGEN}
${PA_WAS_GCOPTION}
${PA_MIN_HEAP}
${PA_MAX_HEAP}
${PA_MIN_YGEN}
${PA_MAX_YGEN}
${PA_GCOPTION}
${CLUSTER_NAME}
${CLUSTER_NAME_LC}
${DNS_ZONE}
${DNS_ZONE_DERIVED}
${PRIMARY_DNS_ZONE}
${PRIMARY_DNS_ZONE_DERIVED}
${IRSA_PING_ANNOTATION_KEY_VALUE}
${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}'

########################################################################################################################
# Export some derived environment variables.
########################################################################################################################
add_derived_variables() {
  # The directory within the cluster state repo for the region's manifest files.
  export CLUSTER_STATE_REPO_PATH_DERIVED="\${REGION_NICK_NAME}"

  # Server profile URL and branch. The directory is in each app's env_vars file.
  export SERVER_PROFILE_URL_DERIVED="\${CLUSTER_STATE_REPO_URL}"
  export SERVER_PROFILE_BRANCH_DERIVED="\${CLUSTER_STATE_REPO_BRANCH}"

  # Zone for this region and the primary region.
  export DNS_ZONE_DERIVED="\${DNS_ZONE}"
  export PRIMARY_DNS_ZONE_DERIVED="\${PRIMARY_DNS_ZONE}"

  # Zone for this region and the primary region
  if "${IS_BELUGA_ENV:-false}"; then
    export DNS_ZONE="\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${PRIMARY_TENANT_DOMAIN}"
  else
    export DNS_ZONE="\${ENV}-\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${ENV}-\${PRIMARY_TENANT_DOMAIN}"
  fi
}

########################################################################################################################
# Prints a log message prepended with the name of the current script to stdout.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
log() {
  echo "=====> ${SCRIPT_NAME} $1" 2>&1
}

########################################################################################################################
# Invokes pushd on the provided directory but suppresses stdout and stderr.
#
# Arguments
#   $1 -> The directory to push.
########################################################################################################################
pushd_quiet() {
  # shellcheck disable=SC2164
  pushd "$1" >/dev/null 2>&1
}

########################################################################################################################
# Invokes popd but suppresses stdout and stderr.
########################################################################################################################
popd_quiet() {
  # shellcheck disable=SC2164
  popd >/dev/null 2>&1
}

########################################################################################################################
# Verify that the provided binaries are available.
#
# Arguments
#   $@ -> The list of required binaries.
#
# Returns:
#   0 on success; 1 otherwise.
########################################################################################################################
check_binaries() {
  status=0
  for tool in "$@"; do
    # shellcheck disable=SC2230
    which "${tool}" &>/dev/null
    if test ${?} -ne 0; then
      log "${tool} is required but missing"
      status=1
    fi
  done
  return ${status}
}

########################################################################################################################
# Sets the name-value pairs in the provided file as environment variables.
#
# Arguments
#   $1 -> The environment variables file.
########################################################################################################################
set_env_vars() {
  env_file="$1"
  if test -f "${env_file}"; then
    env_file_bak="${env_file}".bak
    cp "${env_file}" "${env_file_bak}"

    # FIXME: escape variable values with spaces in the future. For now, LAST_UPDATE_REASON is the only one with spaces.
    # The PS/GSO teams have been informed to quote the string if it has spaces or escape the quotes.
    # Remove LAST_UPDATE_REASON because it has spaces. The source will fail otherwise.
    sed -i.bak '/^LAST_UPDATE_REASON=.*$/d' "${env_file_bak}"
    rm -f "${env_file_bak}".bak

    set -a
    # shellcheck disable=SC1090
    source "${env_file_bak}"
    set +a

    rm -f "${env_file_bak}"
  fi
}

########################################################################################################################
# Returns the initial git revision.
#
# Returns
#   The initial git revision
########################################################################################################################
get_initial_git_rev() {
  git log --reverse --format=format:%H 2> /dev/null | head -1
}

########################################################################################################################
# Gets the file that has all ping-cloud secrets. If the file is found, then its contents will be written to the provided
# output file. If the git_rev revision is provided, then the secrets file will be obtained from that revision. Otherwise,
# it will be obtained from the HEAD of the current revision.
#
# Arguments
#   $1 -> The output file to which to write secrets.yaml. If the secrets.yaml file is not found, then nothing will be
#         written to the file.
#   $2 -> Optional. The git revision.
########################################################################################################################
get_ping_cloud_secrets_file() {
  out_file="$1"
  git_rev="$2"

  # Switch to the git revision, if provided.
  if test "${git_rev}"; then
    log "Switching to git revision ${git_rev}"
    git checkout --quiet "${git_rev}"
  fi

  # Get the full path of the secrets.yaml file that has all ping-cloud secrets.
  secrets_yaml="$(git grep -e PING_IDENTITY_DEVOPS | grep -v '\$' | head -1 | cut -d: -f1)"

  # If found, copy it to the provided output file in JSON format.
  # NOTE: it's safer to use kubectl here than a YAML parser like yq, whose options vary by version of the tool, OS, etc.
  if test "${secrets_yaml}"; then
    log "Attempting to transform ${secrets_yaml} from YAML to JSON into ${out_file}"
    if ! kubectl apply -f "${secrets_yaml}" -o json --dry-run 2>/dev/null > "${out_file}"; then
      log "Unable to parse secrets from file ${secrets_yaml}"
    fi
  else
    log "ping-cloud secrets.yaml file not found in revision: ${git_rev:-HEAD}"
  fi

  # Switch back to previous git revision.
  if test "${git_rev}"; then
    log "Switching back to previous git revision"
    git checkout --quiet -
  fi
}

########################################################################################################################
# Retrieve the base64-decoded value of the secret from the provided file. If the secret is not found, then an empty
# string is returned.
#
# Arguments
#   $1 -> The secret name.
#   $2 -> The file containing the secret.
#
# Returns
#   The base64-decoded value of the secret, or empty, if the secret is not found.
########################################################################################################################
get_secret_from_file() {
  secret="$1"
  secret_file="$2"
  secret_value="$(jq -r ".items[].data.${secret}" < "${secret_file}" | grep -v ^null)"
  if test "${secret_value}"; then
    echo "${secret_value}" | base64 "${BASE64_DECODE_OPT}"
  fi
}

########################################################################################################################
# Retrieve the minimum required secrets required to stand up the out-of-the-box ping-cloud stack into the following
# environment variables:
#
#   - PING_IDENTITY_DEVOPS_USER - The devops user
#   - PING_IDENTITY_DEVOPS_KEY - The devops key
#   - ID_RSA_FILE - SSH key for cloning from git
#
# If all the secrets are found, then a global variable named ALL_MIN_SECRETS_FOUND will be set to true.
########################################################################################################################
get_min_required_secrets() {
  ping_cloud_secrets_yaml="$(mktemp)"
  log "Attempting to get ping-cloud secrets.yaml into ${ping_cloud_secrets_yaml}"

  # Try to get a secrets.yaml file from the initial git revision.
  get_ping_cloud_secrets_file "${ping_cloud_secrets_yaml}" "$(get_initial_git_rev)"

  # If secrets.yaml has no contents, then try to get it from the latest git revision.
  if ! test -s "${ping_cloud_secrets_yaml}"; then
    get_ping_cloud_secrets_file "${ping_cloud_secrets_yaml}"
  fi

  # If secrets.yaml has contents, then attempt to retrieve each required secret.
  ALL_MIN_SECRETS_FOUND=false
  if test -s "${ping_cloud_secrets_yaml}"; then
    ALL_MIN_SECRETS_FOUND=true

    PING_IDENTITY_DEVOPS_USER="$(get_secret_from_file 'PING_IDENTITY_DEVOPS_USER' "${ping_cloud_secrets_yaml}")"
    if ! test "${PING_IDENTITY_DEVOPS_USER}"; then
      log "PING_IDENTITY_DEVOPS_USER not found in ${ping_cloud_secrets_yaml}"
      ALL_MIN_SECRETS_FOUND=false
    fi

    PING_IDENTITY_DEVOPS_KEY="$(get_secret_from_file 'PING_IDENTITY_DEVOPS_KEY' "${ping_cloud_secrets_yaml}")"
    if ! test "${PING_IDENTITY_DEVOPS_KEY}"; then
      log "PING_IDENTITY_DEVOPS_KEY not found in ${ping_cloud_secrets_yaml}"
      ALL_MIN_SECRETS_FOUND=false
    fi

    NEW_RELIC_LICENSE_KEY="$(get_secret_from_file 'NEW_RELIC_LICENSE_KEY' "${ping_cloud_secrets_yaml}")"
    if ! test "${NEW_RELIC_LICENSE_KEY}"; then
      log "NEW_RELIC_LICENSE_KEY not found in ${ping_cloud_secrets_yaml}"
    fi

    ID_RSA_FILE="$(mktemp)"
    get_secret_from_file 'id_rsa' "${ping_cloud_secrets_yaml}" > "${ID_RSA_FILE}"
    if ! test -s "${ID_RSA_FILE}"; then
      log "SSH key not found in ${ID_RSA_FILE}"
      ALL_MIN_SECRETS_FOUND=false
      ID_RSA_FILE=
    fi
  fi

  if test -z "${PING_IDENTITY_DEVOPS_USER}" || test -z "${PING_IDENTITY_DEVOPS_KEY}"; then
    ALL_MIN_SECRETS_FOUND=false

    # Default the dev ops user and key to fake values, if not found in secrets.yaml.
    PING_IDENTITY_DEVOPS_USER="${PING_CLOUD_DEFAULT_DEVOPS_USER}"
    PING_IDENTITY_DEVOPS_KEY='2FederateM0re'
  fi

  log "Using PING_IDENTITY_DEVOPS_USER -> ${PING_IDENTITY_DEVOPS_USER}"
}

########################################################################################################################
# Run a git diff from a source branch to a destination branch to determine the list of files that are deleted or renamed
# in the destination branch for a particular directory. It handles whitespaces in filenames and addresses PDO-2066.
#
# Arguments
#   $1 -> The source branch.
#   $2 -> The destination branch.
#   $3 -> The directory to diff.
#
# Returns:
#   The list of deleted and renamed files in the destination branch.
########################################################################################################################
git_diff() {
  src_branch="$1"
  dst_branch="$2"
  diff_dir="$3"

  # Regex for the status of a renamed file in the git output, e.g. R069, R085, R099, R100, etc.
  file_renamed_regex='^R([0-9]{3})$'

  # The following while-loop handles renamed and deleted files in the "git diff" output. Here's an explanation for the
  # processing that happens with an example for each case:
  #
  # 1. A renamed file will contain 3 lines of output - the rename code (e.g. 'R090'), the source file and the target
  #    file. We must accept the line immediately after 'R090' (i.e. k8s-configs/us-east-2/ping-cloud/orig-secrets.yaml)
  #    but reject the line following it (i.e. k8s-configs/base/orig-secrets.yaml):
  #
  #       R090
  #       k8s-configs/us-east-2/ping-cloud/orig-secrets.yaml
  #       k8s-configs/base/orig-secrets.yaml
  #
  # 2. A deleted file will contain 2 lines of output - the delete code (i.e. 'D') and the name of the deleted file. We
  #    must accept the line immediately after 'D' (i.e. k8s-configs/base/cluster-tools/known-hosts-config.yaml):
  #
  #       D
  #       k8s-configs/base/cluster-tools/known-hosts-config.yaml
  #
  diff_files=
  skip_next_line=false

  while IFS= read -r -d '' line; do
    # Skip this line because we're processing a renamed file.
    if "${skip_next_line}"; then
      skip_next_line=false
      continue
    fi

    # Remove the null character delimiter (i.e. ^@) added by the '-z' argument of "git diff".
    sanitized_line="$(printf '%q\n' "${line}")"

    # The file was renamed in the target branch but not deleted.
    if [[ "${sanitized_line}" =~ ${file_renamed_regex} ]]; then
      file_deleted=false
      continue

    # The file was deleted in the target branch.
    elif [[ "${sanitized_line}" = 'D' ]]; then
      file_deleted=true
      continue
    fi

    # Accumulate the changed files in the return variable.
    test "${diff_files}" &&
        diff_files="${diff_files} ${sanitized_line}" ||
        diff_files="${sanitized_line}"

    # If the file was deleted, then we don't need to skip the line read in the next iteration. But if it was renamed,
    # then the old and new names will appear in the output one after another, so we must skip the next line.
    if "${file_deleted}"; then
      skip_next_line=false
    else
      skip_next_line=true
    fi
  done < <(git diff -z --diff-filter=D --diff-filter=R --name-status "${src_branch}" "${dst_branch}" -- "${diff_dir}")

  echo "${diff_files}"
}

########################################################################################################################
# Copy profiles files that were deleted or renamed from a default CDE branch into its new one.
#
# Arguments
#   $1 -> The new branch for a default CDE branch.
########################################################################################################################
handle_changed_profiles() {
  NEW_BRANCH="$1"
  DEFAULT_CDE_BRANCH="${NEW_BRANCH##*-}"

  log "Reconciling '${PROFILES_DIR}' diffs between '${DEFAULT_CDE_BRANCH}' and its new branch '${NEW_BRANCH}'"

  git checkout --quiet "${NEW_BRANCH}"
  new_files="$(git_diff "${DEFAULT_CDE_BRANCH}" HEAD "${PROFILES_DIR}")"

  if ! test "${new_files}"; then
    log "No changed '${PROFILES_DIR}' files to copy '${DEFAULT_CDE_BRANCH}' to its new branch '${NEW_BRANCH}'"
  else
    log "DEBUG: Found the following new files in branch '${DEFAULT_CDE_BRANCH}':"
    echo "${new_files}"
    echo "${new_files}" | xargs git checkout "${DEFAULT_CDE_BRANCH}"
  fi

  # Copy artifact-list.json files from the default CDE branch into the new branch but with a .old extension.
  artifact_json_files="$(find "${PROFILES_DIR}" -name ${ARTIFACTS_JSON_FILE_NAME})"
  log "Found the following ${ARTIFACTS_JSON_FILE_NAME} files: ${artifact_json_files}"

  for artifact_file in ${artifact_json_files}; do
    log "Copying file ${DEFAULT_CDE_BRANCH}:${artifact_file} to the same location on ${NEW_BRANCH} with .old extension"
    git show "${DEFAULT_CDE_BRANCH}:${artifact_file}" > "${artifact_file}".old
  done

  msg="Copied changed '${PROFILES_DIR}' files from '${DEFAULT_CDE_BRANCH}' to its new branch '${NEW_BRANCH}'"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Create secrets.yaml.old and sealed-secrets.yaml.old files if different between the default CDE branch and its new
# one. This makes it easier for the operator to see the differences in secrets between the two branches.
#
# Arguments
#   $1 -> The new branch for a default CDE branch.
#   $2 -> The primary region.
########################################################################################################################
handle_changed_k8s_secrets() {
  NEW_BRANCH="$1"
  PRIMARY_REGION="$2"

  DEFAULT_CDE_BRANCH="${NEW_BRANCH##*-}"
  log "Handling changes to ${SECRETS_FILE_NAME} and ${SEALED_SECRETS_FILE_NAME} in branch '${DEFAULT_CDE_BRANCH}'"

  # In v1.6:
  #   - Secrets and the OOTB secrets for a release are present under <region>/ping-cloud/[orig-]secrets.yaml and
  #     <region>/cluster-tools/[orig-]secrets.yaml for each region.
  #   - Sealed secrets are present under <region>/sealed-secrets.yaml.

  # In v1.7 and later:
  #   - Secrets, OOTB secrets and sealed secrets are all present under base/.

  # First switch to the default CDE branch.
  git checkout --quiet "${DEFAULT_CDE_BRANCH}"
  old_secrets_dir="$(mktemp -d)"

  for secrets_file_name in "${SECRETS_FILE_NAME}" "${ORIG_SECRETS_FILE_NAME}" "${SEALED_SECRETS_FILE_NAME}"; do
    log "Handling changes to ${secrets_file_name} in branch '${DEFAULT_CDE_BRANCH}'"
    old_secrets_file="${old_secrets_dir}/${secrets_file_name}"

    # The >= v1.7 case:
    all_secret_files="$(git ls-files "${K8S_CONFIGS_DIR}/${BASE_DIR}/${secrets_file_name}")"
    if ! test "${all_secret_files}"; then
      # The v1.6 case:
      if test "${secrets_file_name}" = "${SEALED_SECRETS_FILE_NAME}"; then
        file_path="${K8S_CONFIGS_DIR}/${PRIMARY_REGION}/${secrets_file_name}"
      else
        # The '*' below may be one of 'ping-cloud' or 'cluster-tools' as noted above.
        file_path="${K8S_CONFIGS_DIR}/${PRIMARY_REGION}/*/${secrets_file_name}"
      fi
      all_secret_files="$(git ls-files "${file_path}")"
    fi

    log "Found '${secrets_file_name}' files: ${all_secret_files}"
    for secret_file in ${all_secret_files}; do
      git show "${DEFAULT_CDE_BRANCH}:${secret_file}" >> "${old_secrets_file}"
      echo >> "${old_secrets_file}"
    done
  done # secrets loop

  # Switch to the new CDE branch and copy over the old secrets, if they're different.
  git checkout --quiet "${NEW_BRANCH}"

  secret_files="$(find "${old_secrets_dir}" -type f)"
  for file in ${secret_files}; do
    file_name="$(basename "${file}")"
    dst_file="${K8S_CONFIGS_DIR}/${BASE_DIR}/${file_name}"

    if diff -qbB "${file}" "${dst_file}"; then
      log "No difference found between ${file_name} and ${dst_file}"
    else
      cp "${file}" "${dst_file}.old"
    fi
  done

  msg="Done creating ${SECRETS_FILE_NAME}.old and ${SEALED_SECRETS_FILE_NAME}.old in branch '${NEW_BRANCH}'"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Copy new k8s-configs files from the default CDE branch into its new one.
#
# Arguments
#   $1 -> The new branch for a default CDE branch.
########################################################################################################################
handle_changed_k8s_configs() {
  NEW_BRANCH="$1"

  DEFAULT_CDE_BRANCH="${NEW_BRANCH##*-}"
  log "Handling non Beluga-owned files in branch '${DEFAULT_CDE_BRANCH}'"

  log "Reconciling '${K8S_CONFIGS_DIR}' diffs between '${DEFAULT_CDE_BRANCH}' and its new branch '${NEW_BRANCH}'"
  git checkout --quiet "${NEW_BRANCH}"
  new_files="$(git_diff "${DEFAULT_CDE_BRANCH}" HEAD "${K8S_CONFIGS_DIR}")"

  if ! test "${new_files}"; then
    log "No changed '${K8S_CONFIGS_DIR}' files to copy '${DEFAULT_CDE_BRANCH}' to its new branch '${NEW_BRANCH}'"
    return
  fi

  log "DEBUG: Found the following new files in branch '${DEFAULT_CDE_BRANCH}':"
  echo "${new_files}"

  KUSTOMIZATION_FILE="${CUSTOM_RESOURCES_REL_DIR}/kustomization.yaml"
  KUSTOMIZATION_BAK_FILE="${KUSTOMIZATION_FILE}.bak"

  # Special-case the handling all files owned by PS/GSO.

  # 1. Copy the custom-patches.yaml file (owned by PS/GSO) as is.
  # 2. Copy the custom-resources/kustomization.yaml, which references the custom resources (also owned by PS/GSO) as is.
  for file in ${CUSTOM_RESOURCES_REL_DIR}/kustomization.yaml ${CUSTOM_PATCHES_REL_FILE_NAME}; do
    if git show "${DEFAULT_CDE_BRANCH}:${file}" &> /dev/null; then
      log "Copying file ${DEFAULT_CDE_BRANCH}:${file} to the same location on ${NEW_BRANCH}"
      git show "${DEFAULT_CDE_BRANCH}:${file}" > "${file}"
    else
      log "${file} does not exist in default CDE branch ${DEFAULT_CDE_BRANCH}"
    fi
  done

  for new_file in ${new_files}; do
    # Ignore Beluga-owned files.
    new_file_basename="$(basename "${new_file}")"
    if echo "${beluga_owned_k8s_files}" | grep -q "@${new_file_basename}"; then
      log "Ignoring file ${DEFAULT_CDE_BRANCH}:${new_file} since it is a Beluga-owned file"
      continue
    fi

    # Copy files in the custom-resources section (owned by PS/GSO) as is.
    new_file_dirname="$(dirname "${new_file}")"
    if test "${new_file_dirname##*/}" = "${CUSTOM_RESOURCES_DIR}"; then
      log "Copying custom resource file ${DEFAULT_CDE_BRANCH}:${new_file} to the same location on ${NEW_BRANCH}"
      git show "${DEFAULT_CDE_BRANCH}:${new_file}" > "${new_file}"
      continue
    fi

    # Copy non-YAML files (owned by PS/GSO) to the same location on the new branch, e.g. sealingkey.pem
    new_file_ext="${new_file_basename##*.}"
    if test "${new_file_ext}" != 'yaml'; then
      log "Copying non-YAML file ${DEFAULT_CDE_BRANCH}:${new_file} to the same location on ${NEW_BRANCH}"
      mkdir -p "${new_file_dirname}"
      git show "${DEFAULT_CDE_BRANCH}:${new_file}" > "${new_file}"
      continue
    fi

    log "Copying custom file ${DEFAULT_CDE_BRANCH}:${new_file} into directory ${CUSTOM_RESOURCES_REL_DIR}"
    git show "${DEFAULT_CDE_BRANCH}:${new_file}" > "${CUSTOM_RESOURCES_REL_DIR}/${new_file_basename}"

    log "Adding new resource file ${new_file_basename} to ${KUSTOMIZATION_FILE}"
    new_resource_line="- ${new_file_basename}"

    grep_opts=(-q -e "${new_resource_line}")
    if ! grep "${grep_opts[@]}" "${KUSTOMIZATION_FILE}"; then
      # shellcheck disable=SC1003
      sed -i.bak -e '/^resources:$/a\'$'\n'"${new_resource_line}" "${KUSTOMIZATION_FILE}"
      rm -f "${KUSTOMIZATION_BAK_FILE}"
    fi
  done

  msg="Copied new '${K8S_CONFIGS_DIR}' files '${DEFAULT_CDE_BRANCH}' to its new branch '${NEW_BRANCH}'"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Prints a README containing next steps to take.
########################################################################################################################
print_readme() {
  TAB='    '
  SEPARATOR='^'

  for NEW_BRANCH in ${NEW_BRANCHES}; do
    CDE="${NEW_BRANCH##*-}"
    BRANCH_LINE="${TAB} ${NEW_BRANCH} -> ${CDE}"
    test "${ENV_BRANCH_MAP}" &&
        ENV_BRANCH_MAP="${ENV_BRANCH_MAP}${SEPARATOR}${BRANCH_LINE}" ||
        ENV_BRANCH_MAP="${BRANCH_LINE}"
  done

  echo
  echo '################################################################################'
  echo '#                                    README                                    #'
  echo '################################################################################'
  echo
  echo "- The following new CDE branches have been created for the default ones:"
  echo
  echo "${ENV_BRANCH_MAP}" | tr "${SEPARATOR}" '\n'
  echo
  echo "- No changes have been made to the default CDE branches."
  echo
  echo "- The new CDE branches are just local branches and not pushed to the server."
  echo "  They contain cluster state valid for '${NEW_VERSION}'."
  echo

  if "${RESET_TO_DEFAULT}"; then
    echo "- All environment variables have been reset to the default for '${NEW_VERSION}'."
  else
    echo "- Environment variables have been migrated to '${NEW_VERSION}' with the exception"
    echo "  of app JVM settings."
  fi
  echo
  echo "    - The '${ENV_VARS_FILE_NAME}' files have been copied over from the default CDE branch"
  echo "      with a suffix of '.old', but they are not sourced from any kustomization.yaml."
  echo
  echo "    - Use the '${ENV_VARS_FILE_NAME}.old' files as a reference to fix up any"
  echo "      discrepancies in the new '${ENV_VARS_FILE_NAME}'."
  echo
  echo "    - WARNING: changing app JVM settings will require related changes to the"
  echo "      replica set of the apps. Make those changes to '${CUSTOM_PATCHES_FILE_NAME}'."
  echo "      There is a '${CUSTOM_PATCHES_SAMPLE_FILE_NAME}' peer file with some examples"
  echo "      showing how to patch HPA settings, replica count, mem/cpu request/limits, etc."
  echo

  if "${ALL_MIN_SECRETS_FOUND}"; then
    echo "- All secrets have been reset to the default for '${NEW_VERSION}'."
  else
    echo "- All but the following secrets have been reset to the default for '${NEW_VERSION}'"
    echo
    echo "    - The 'PING_IDENTITY_DEVOPS_KEY' contains a fake key. If using devops licenses,"
    echo "      it must be updated to the key for '${PING_CLOUD_DEFAULT_DEVOPS_USER}'."
    echo
    echo "    - The git SSH key in 'argo-git-deploy' and 'ssh-id-key-secret' also"
    echo "      contain fake values and must be updated."
    echo
    echo "    - Reach out to the platform team to get the right values for these secrets."
  fi
  echo
  echo "- The '${SECRETS_FILE_NAME}', '${ORIG_SECRETS_FILE_NAME}' and '${SEALED_SECRETS_FILE_NAME}'"
  echo "  files have been copied over from the default CDE branch with a suffix of '.old',"
  echo "  but they are not sourced from any kustomization.yaml. Use the '*secrets.yaml.old'"
  echo "  files as a reference to fix up the new ones in the following manner:"
  echo
  echo "    - Secrets that are new in '${NEW_VERSION}' must be configured and re-sealed."
  echo
  echo "    - Secrets that are no longer used in '${NEW_VERSION}' must be removed."
  echo
  echo "    - The '${ORIG_SECRETS_FILE_NAME}' file contains the complete list of secrets"
  echo "      for '${NEW_VERSION}'."
  echo
  echo "    - Note that the seal.sh script is recommended if sealing all secrets at once"
  echo "      since it handles both secrets inherited from '${PING_CLOUD_BASE}' and"
  echo "      those defined directly within '${CLUSTER_STATE_REPO}'."
  echo

  if ! "${RESET_TO_DEFAULT}"; then
    echo "- All server profile changes under '${PROFILES_DIR}' have been migrated."
  else
    echo "- Changes under '${PROFILES_DIR}' were not migrated upon request. If profile"
    echo "  customizations have been made, then they need to be manually migrated to"
    echo "  the new CDE branches."
    echo
    echo "    - The following files in '${PROFILES_DIR}' are typically customized:"
    echo
    echo "        - PingFederate and PingDirectory artifact-list.json"
    echo "        - PingFederate language-pack and template files"
    echo "        - PingDirectory schema and dsconfig files"
    echo "        - PingDirectory 03-passthrough-auth-plugin.dsconfig"
    echo
    echo "    - To get a list of all of the '${PROFILES_DIR}' files that are different"
    echo "      between a default CDE branch and its new branch, run:"
    echo
    echo "          git diff --name-status --diff-filter=D --diff-filter=R \\"
    echo "              <default-cde-branch> <new-cde-branch> -- ${PROFILES_DIR}"
  fi
  echo

  if ! "${RESET_TO_DEFAULT}"; then
    echo "- All Kubernetes customizations under '${K8S_CONFIGS_DIR}' have been migrated"
    echo "  to the '${CUSTOM_RESOURCES_REL_DIR}' directory."
    echo
    echo "    - New custom resources should only be added under this directory in future."
    echo
    echo "    - Similarly, patches to out-of-the-box resources should only go"
    echo "      into '${CUSTOM_PATCHES_REL_FILE_NAME}'."
  else
    echo "- Changes under '${K8S_CONFIGS_DIR}' were not migrated upon request. If"
    echo "  Kubernetes customizations have been made, then they need to be manually"
    echo "  migrated to the new CDE branches."
    echo
    echo "    - The following files in '${K8S_CONFIGS_DIR}' are typically customized:"
    echo
    echo "        - PingDirectory descriptor.json for multi-region customers"
    echo "        - Additional custom certificates/ingresses or patches to existing ones"
    echo
    echo "    - To get a list of all '${K8S_CONFIGS_DIR}' files that are different"
    echo "      between a default CDE branch and its new branch, run:"
    echo
    echo "          git diff --name-status --diff-filter=D --diff-filter=R \\"
    echo "              <default-cde-branch> <new-cde-branch> -- ${K8S_CONFIGS_DIR}"
  fi
  echo

  echo "- When the script finishes to completion:"
  echo
  echo "    - Run the following command from the '${K8S_CONFIGS_DIR}' directory:"
  echo
  echo "          ./git-ops-command.sh <REGION_DIR> > /tmp/<REGION_DIR>.yaml"
  echo
  echo "    - Verify that the generated manifest looks right for the CDE and region."
  echo
  echo "    - Repeat the command for every region for multi-region customers."
  echo
  echo "    - Pay special attention to app JVM settings and ensure that they are"
  echo "      adequate for the type and size of the CDE. Reach out to the Beluga"
  echo "      team on sizing guidance."
  echo

  echo "- After verifying the generated manifest, rename the default CDE branches to"
  echo "  backup branches:"
  echo
  echo "      git checkout <default-cde-branch>"
  echo "      git branch -m <old-version>-<default-cde-branch>"
  echo
  echo "- Rename the new CDE branches to their corresponding default branch name:"
  echo
  echo "      git checkout <new-cde-branch>"
  echo "      git branch -m <default-cde-branch>"
  echo
  echo "- Create SRE tickets for platform upgrades for '${NEW_VERSION}', e.g."
  echo "  ASG fixes, EKS upgrades, etc."
  echo
  echo "- Run any required commands from the management node to prepare the"
  echo "  cluster for '${NEW_VERSION}', e.g. delete flux, elastic-stack-logging"
  echo "  namespaces, etc."
  echo
  echo "- Push the newly migrated CDE branches to the server."
}

########################################################################################################################
# Log on non-zero exit code.
########################################################################################################################
finalize() {
  exit_code="$?"
  if test "${exit_code}" -ne 0; then
    echo
    echo "ERROR!!! ${SCRIPT_NAME} failed with exit code ${exit_code}"
    echo
    echo 'Grab the output of the script and reach out to the Beluga team'
    echo 'for support with updating the cluster-state-repo'
    exit "${exit_code}"
  fi

  # Go back to previous git branch.
  git checkout --quiet "${CURRENT_BRANCH}"
}

### SCRIPT START ###

# Trap all exit codes to detect non-zero exit codes and log on it.
trap 'finalize' EXIT

# Save the the script name to include in log messages.
SCRIPT_NAME="$(basename "$0")"

# Check required binaries.
check_binaries 'kubectl' 'git' 'base64' 'jq' 'envsubst' || exit 1

# Verify that required environment variable NEW_VERSION is set.
if test -z "${NEW_VERSION}"; then
  log 'NEW_VERSION environment variable must be set before invoking this script'
  exit 1
fi

# Perform some basic validation of the cluster state repo.
if test ! -d "${K8S_CONFIGS_DIR}"; then
  log 'Copy this script to the base directory of the cluster state repo and run it from there'
  exit 1
fi

# FIXME: This is actually better for checking the status
#
# if test -n "$(git status -s)"; then
#   echo commands-to-fix-local-changes
# fi
#
# However, there is a bug in the wrapper script (shipped code) that prevents it from working correctly. The wrapper has
# been fixed in v1.8. This check should be fixed in v1.9.

if ! git diff-index --quiet HEAD --; then
  echo
  echo 'There are local changes, which must be resolved before running this script:'
  echo
  git status

  echo
  echo 'If local changes are required, then commit them by running these commands:'
  echo
  echo '    git add .                       # Stage all local changes for commit'
  echo '    git commit -m <commit-message>  # Commit the changes'
  echo
  echo 'If local changes are unnecessary, then get rid of them by running these commands:'
  echo
  echo '    git reset --hard HEAD     # Get rid of staged and un-staged modifications'
  echo '    git clean -fdx            # Get rid of untracked files and directories (including ignored ones)'
  echo

  exit 1
fi

# Save off the current branch so we can switch back to it at the end of the script.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Validate that a CDE branch exists for every environment.
ALL_ENVIRONMENTS='dev test stage prod'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

NEW_BRANCHES=
REPO_STATUS=0

for ENV in ${ENVIRONMENTS}; do
  test "${ENV}" = 'prod' &&
      DEFAULT_CDE_BRANCH='master' ||
      DEFAULT_CDE_BRANCH="${ENV}"

  log "Validating that '${CLUSTER_STATE_REPO}' has branch: '${DEFAULT_CDE_BRANCH}'"
  git checkout --quiet "${DEFAULT_CDE_BRANCH}"
  if test $? -ne 0; then
    log "CDE branch '${DEFAULT_CDE_BRANCH}' does not exist in '${CLUSTER_STATE_REPO}'"
    REPO_STATUS=1
  fi

  NEW_BRANCH="${NEW_VERSION}-${DEFAULT_CDE_BRANCH}"
  test "${NEW_BRANCHES}" &&
      NEW_BRANCHES="${NEW_BRANCHES} ${NEW_BRANCH}" ||
      NEW_BRANCHES="${NEW_BRANCH}"
done

test "${REPO_STATUS}" -ne 0 && exit 1

# Clone ping-cloud-base, if necessary.
PING_CLOUD_BASE_REPO_URL="${PING_CLOUD_BASE_REPO_URL:-https://github.com/pingidentity/ping-cloud-base}"

if ! test "${NEW_PING_CLOUD_BASE_REPO}"; then
  # Clone ping-cloud-base at the new version
  NEW_PCB_REPO="$(mktemp -d)"
  pushd_quiet "${NEW_PCB_REPO}"

  log "Cloning ${PING_CLOUD_BASE}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL} to '${NEW_PCB_REPO}'"
  git clone -c advice.detachedHead=false --depth 1 --branch "${NEW_VERSION}" "${PING_CLOUD_BASE_REPO_URL}"

  if test $? -ne 0; then
    log "Unable to clone ${PING_CLOUD_BASE_REPO_URL}@${NEW_VERSION} from ${PING_CLOUD_BASE_REPO_URL}"
    popd_quiet
    exit 1
  fi

  NEW_PING_CLOUD_BASE_REPO="${NEW_PCB_REPO}/${PING_CLOUD_BASE}"
  popd_quiet
fi

# Generate cluster state code for new version.

# NOTE: This entire block of code is being run from the cluster-state-repo directory. All non-absolute paths are
# relative to this directory.

# The base environment variables file that's common to all regions.
BASE_ENV_VARS="${K8S_CONFIGS_DIR}/${BASE_DIR}/${ENV_VARS_FILE_NAME}"

# Get the minimum required ping-cloud secrets (currently, the devops user/key and SSH git key).
get_min_required_secrets

# For each environment:
#   - Generate code for all its regions
#   - Push code for all its regions into new branches
for ENV in ${ENVIRONMENTS}; do # ENV loop
  test "${ENV}" = 'prod' &&
      DEFAULT_CDE_BRANCH='master' ||
      DEFAULT_CDE_BRANCH="${ENV}"

  NEW_BRANCH="${NEW_VERSION}-${DEFAULT_CDE_BRANCH}"
  log "Updating branch '${NEW_BRANCH}' for CDE '${ENV}'"

  log "Switching to branch ${DEFAULT_CDE_BRANCH} to determine deployed regions"
  git checkout --quiet "${DEFAULT_CDE_BRANCH}"

  # Get the names of all the regional directories. Note that this may not be the actual region, rather it's the nick
  # name of the region.
  REGION_DIRS="$(find "${K8S_CONFIGS_DIR}" \
      -mindepth 1 -maxdepth 1 \
      -type d \( ! -name "${BASE_DIR}" \) \
      -exec basename {} \;)"

  log "Environment '${ENV}' has the following region directories:"
  echo "${REGION_DIRS}"

  # Code for this environment will be generated in the following directory. Each region will get its own sub-directory
  # under this directory.
  TENANT_CODE_DIR="$(mktemp -d)"

  # The file into which the primary region directory name will be stored for later use.
  PRIMARY_REGION_DIR_FILE="$(mktemp)"

  for REGION_DIR in ${REGION_DIRS}; do # REGION loop for generate
    # Perform the code generation in a sub-shell so it doesn't pollute the current shell with environment variables.
    (
      # Common environment variables for the region
      REGION_ENV_VARS="${K8S_CONFIGS_DIR}/${REGION_DIR}/${ENV_VARS_FILE_NAME}"

      # App-specific environment variables for the region
      APP_ENV_VARS_FILES="$(find "${K8S_CONFIGS_DIR}/${REGION_DIR}" -type f -mindepth 2 -name "${ENV_VARS_FILE_NAME}")"

      # Set the environment variables in the order: region-specific, app-specific (within the region directories),
      # base. This will ensure that derived variables are set correctly.
      set_env_vars "${REGION_ENV_VARS}"
      for ENV_VARS_FILE in ${APP_ENV_VARS_FILES}; do
        set_env_vars "${ENV_VARS_FILE}"
      done
      set_env_vars "${BASE_ENV_VARS}"

      # Set the TARGET_DIR to the right directory for the region.
      TARGET_DIR="${TENANT_CODE_DIR}/${REGION_DIR}"

      # Generate code now that we have set all the required environment variables
      log "Generating code for region '${REGION_DIR}' and branch '${NEW_BRANCH}' into '${TARGET_DIR}'"
      (
        # If resetting to default, then use defaults for these variables instead of migrating them.
        if "${RESET_TO_DEFAULT}"; then
          log "Resetting variables to the default or out-of-the-box values per request"
          unset LETS_ENCRYPT_SERVER
        fi

        export PING_IDENTITY_DEVOPS_KEY="${PING_IDENTITY_DEVOPS_KEY}"
        set -x
        QUIET=true \
            TARGET_DIR="${TARGET_DIR}" \
            LAST_UPDATE_REASON="Updating cluster-state-repo to version ${NEW_VERSION}" \
            K8S_GIT_URL="${PING_CLOUD_BASE_REPO_URL}" \
            K8S_GIT_BRANCH="${NEW_VERSION}" \
            ENVIRONMENTS="${NEW_BRANCH}" \
            PING_IDENTITY_DEVOPS_USER="${PING_IDENTITY_DEVOPS_USER}" \
            SSH_ID_PUB_FILE="${ID_RSA_FILE}" \
            SSH_ID_KEY_FILE="${ID_RSA_FILE}" \
            "${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR}/generate-cluster-state.sh"
      )
      GEN_RC=$?
      if test ${GEN_RC} -ne 0; then
        log "Error generating code for region '${REGION_DIR}' and branch '${NEW_BRANCH}': ${GEN_RC}"
        exit ${GEN_RC}
      fi
      log "Done generating code for region '${REGION_DIR}' and branch '${NEW_BRANCH}' into '${TARGET_DIR}'"

      # Persist the primary region's directory name for later use.
      IS_PRIMARY=false
      if test "${TENANT_DOMAIN}" = "${PRIMARY_TENANT_DOMAIN}"; then
        IS_PRIMARY=true
        echo "${REGION_DIR}" > "${PRIMARY_REGION_DIR_FILE}"
      fi

      # For every env_vars file in the new version, populate the old values into an env_vars.old file.
      ENV_VARS_FILES="$(find "${TARGET_DIR}" -name "${ENV_VARS_FILE_NAME}" -type f)"

      # Add some derived environment variables for substitution.
      add_derived_variables

      for ENV_VARS_FILE in ${ENV_VARS_FILES}; do # Loop for env_vars.old
        OLD_ENV_VARS_FILE="${ENV_VARS_FILE}".old

        DIR_NAME="$(dirname "${ENV_VARS_FILE}")"
        DIR_NAME="${DIR_NAME##*/}"

        if test "${DIR_NAME}" = "${BASE_DIR}"; then
          # Only generate base env_vars.old for primary region.
          if ! "${IS_PRIMARY}"; then
            continue
          fi
          ENV_VARS_TEMPLATE="${NEW_PING_CLOUD_BASE_REPO}/${TEMPLATES_BASE_DIR}/${ENV_VARS_FILE_NAME}"
        elif test "${DIR_NAME}" = "${REGION_DIR}"; then
          ENV_VARS_TEMPLATE="${NEW_PING_CLOUD_BASE_REPO}/${TEMPLATES_REGION_DIR}/${ENV_VARS_FILE_NAME}"
        else
          # Copy the env_vars under ping app-specific directories as is to an env_vars.old in the generated code
          # directory.
          app_env_vars_file="$(git ls-files "*/${DIR_NAME}/env_vars" | grep "${REGION_DIR}" | head -1)"

          if test "${app_env_vars_file}"; then
            log "Copying ${app_env_vars_file} from ${DEFAULT_CDE_BRANCH} to ${OLD_ENV_VARS_FILE}"
            git show "${DEFAULT_CDE_BRANCH}:${app_env_vars_file}" > "${OLD_ENV_VARS_FILE}"
          else
            log "Not an app-specific env_vars file: ${ENV_VARS_FILE}"
          fi

          continue
        fi

        log "Creating '${OLD_ENV_VARS_FILE}' for region '${REGION_DIR}' and branch '${NEW_BRANCH}'"
        envsubst "${ENV_VARS_TO_SUBST}" < "${ENV_VARS_TEMPLATE}" > "${OLD_ENV_VARS_FILE}"

        # If there are no differences between env_vars and env_vars.old, delete the old one.
        if diff -qbB "${ENV_VARS_FILE}" "${OLD_ENV_VARS_FILE}"; then
          log "No difference found between ${ENV_VARS_FILE} and ${OLD_ENV_VARS_FILE} - removing the old one"
          rm -f "${OLD_ENV_VARS_FILE}"
        fi

      done # Loop for env_vars.old
    )
  done # REGION loop for generate

  # Determine the primary region. If we can't, then error out.
  PRIMARY_REGION_DIR="$(cat "${PRIMARY_REGION_DIR_FILE}")"
  if test "${PRIMARY_REGION_DIR}"; then
    log "Primary region directory for CDE '${ENV}': '${PRIMARY_REGION_DIR}'"
  else
    log "Primary region is unknown for CDE '${ENV}'"
    exit 1
  fi

  # Sort the regions such that the primary region is first in order.
  REGION_DIRS_SORTED="${PRIMARY_REGION_DIR}"
  for REGION_DIR in ${REGION_DIRS}; do # REGION sort loop
    if test "${PRIMARY_REGION_DIR}" != "${REGION_DIR}"; then
      REGION_DIRS_SORTED="${REGION_DIRS_SORTED} ${REGION_DIR}"
    fi
  done # REGION sort loop

  log "Region directories in sorted order for CDE '${ENV}': ${REGION_DIRS_SORTED}"
  for REGION_DIR in ${REGION_DIRS_SORTED}; do # REGION loop for push
    if test "${PRIMARY_REGION_DIR}" = "${REGION_DIR}"; then
      IS_PRIMARY=true
      TYPE='primary'
    else
      IS_PRIMARY=false
      TYPE='secondary'
    fi

    TARGET_DIR="${TENANT_CODE_DIR}/${REGION_DIR}"
    log "Generated code directory for ${TYPE} region '${REGION_DIR}' and CDE '${ENV}': ${TARGET_DIR}"

    log "Creating branch for ${TYPE} region '${REGION_DIR}' and CDE '${ENV}': ${NEW_BRANCH}"
    (
      set -x;
      QUIET=true \
          GENERATED_CODE_DIR="${TARGET_DIR}" \
          IS_PRIMARY=${IS_PRIMARY} \
          ENVIRONMENTS="${NEW_BRANCH}" \
          PUSH_TO_SERVER=false \
          "${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR}/push-cluster-state.sh"
    )
    PUSH_RC=$?
    if test ${PUSH_RC} -ne 0; then
      log "Error creating branch '${NEW_BRANCH}' for ${TYPE} region '${REGION_DIR}' and CDE '${ENV}': ${PUSH_RC}"
      exit ${PUSH_RC}
    fi
    log "Done creating branch '${NEW_BRANCH}' for ${TYPE} region '${REGION_DIR}' and CDE '${ENV}'"

  done # REGION loop for push

  # Create .old files for secrets.yaml and sealed-secrets.yaml files so it's easy to see the differences in a pinch.
  handle_changed_k8s_secrets "${NEW_BRANCH}" "${PRIMARY_REGION_DIR}"

  # If requested, copy profiles files that were deleted or renamed from the default CDE branch into its new branch.
  if "${RESET_TO_DEFAULT}"; then
    log "Not migrating '${PROFILES_DIR}' because migration was explicitly skipped"
  else
    handle_changed_profiles "${NEW_BRANCH}"
  fi

  # If requested, copy new k8s-configs files from the default CDE branches into their corresponding new branches.
  if "${RESET_TO_DEFAULT}"; then
    log "Not migrating '${K8S_CONFIGS_DIR}' because migration was explicitly skipped"
  else
    handle_changed_k8s_configs "${NEW_BRANCH}"
  fi

  log "Done updating branch '${NEW_BRANCH}' for CDE '${ENV}'"
done # ENV loop

# Print a README of next steps to take.
print_readme
