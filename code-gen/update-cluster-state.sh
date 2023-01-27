#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

# This script may be used to upgrade an existing cluster state repo. It is designed to be non-destructive in that it
# won't push any changes to the server. Instead, it will set up a parallel branch for every CDE branch and/or the
# customer-hub branch as specified through the ENVIRONMENTS environment variable. For example, if the new version is
# v1.7.1 and the ENVIRONMENTS variable override is not provided, then it’ll set up 4 new CDE branches at the new
# version for the default set of environments: v1.7.1-dev, v1.7.1-test, v1.7.1-stage and v1.7.1-master and 1 new
# customer-hub branch v1.7.1-customer-hub.

# NOTE: The script must be run from the root of the cluster state repo clone directory. It acts on the following
# environment variables.
#
#   NEW_VERSION -> Required. The new version of Beluga to which to update the cluster state repo.
#   ENVIRONMENTS -> A space-separated list of environments. Defaults to 'dev test stage prod customer-hub', if unset.
#       If provided, it must contain all or a subset of the environments currently created by the
#       generate-cluster-state.sh script, i.e. dev, test, stage, prod and customer-hub.
#   RESET_TO_DEFAULT -> An optional flag, which if set to true will reset the cluster-state-repo to the OOTB state
#       for the new version. This has the same effect as running the platform code build job that initially seeds the
#       cluster-state repo.

### Global values and utility functions ###

K8S_CONFIGS_DIR='k8s-configs'
COMMON_DIR='common'
BASE_DIR='base'

CODE_GEN_DIR='code-gen'
TEMPLATES_DIR='templates'
TEMPLATES_BASE_DIR="${CODE_GEN_DIR}/${TEMPLATES_DIR}/${COMMON_DIR}/${BASE_DIR}"
TEMPLATES_REGION_DIR="${CODE_GEN_DIR}/${TEMPLATES_DIR}/${COMMON_DIR}/region"

CUSTOM_RESOURCES_DIR='custom-resources'
CUSTOM_PATCHES_FILE_NAME='custom-patches.yaml'
CUSTOM_PATCHES_SAMPLE_FILE_NAME='custom-patches-sample.yaml'
CUSTOM_RESOURCES_REL_DIR="${K8S_CONFIGS_DIR}/${BASE_DIR}/${CUSTOM_RESOURCES_DIR}"
CUSTOM_PATCHES_REL_FILE_NAME="${K8S_CONFIGS_DIR}/${BASE_DIR}/${CUSTOM_PATCHES_FILE_NAME}"

DESCRIPTOR_JSON_FILE_NAME='descriptor.json'

PING_CLOUD_DIR='ping-cloud'
PING_CLOUD_REL_DIR="${K8S_CONFIGS_DIR}/${BASE_DIR}/${PING_CLOUD_DIR}"

ENV_VARS_FILE_NAME='env_vars'
SECRETS_FILE_NAME='secrets.yaml'
ORIG_SECRETS_FILE_NAME='orig-secrets.yaml'
SEALED_SECRETS_FILE_NAME='sealed-secrets.yaml'

CLUSTER_STATE_REPO='cluster-state-repo'
CUSTOMER_HUB='customer-hub'

PING_CLOUD_BASE='ping-cloud-base'

# README global vars
TAB='    '
SEPARATOR='^'

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
@ext-ingresses.yaml \
@seal.sh"

# The list of variables to substitute in env_vars.old files.
# shellcheck disable=SC2016
# Note: ENV_VARS_TO_SUBST is a subset of DEFAULT_VARS within generate-cluster-state.sh. These variables should be kept
# in sync with the following exceptions: LAST_UPDATE_REASON and NEW_RELIC_LICENSE_KEY_BASE64 should only be found
# within DEFAULT_VARS
ENV_VARS_TO_SUBST='${TENANT_NAME}
${PING_IDENTITY_DEVOPS_USER}
${PING_IDENTITY_DEVOPS_KEY}
${SSH_ID_KEY_BASE64}
${IS_MULTI_CLUSTER}
${PLATFORM_EVENT_QUEUE_NAME}
${ORCH_API_SSM_PATH_PREFIX}
${SERVICE_SSM_PATH_PREFIX}
${REGION}
${REGION_NICK_NAME}
${PRIMARY_REGION}
${TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN}
${PRIMARY_TENANT_DOMAIN_DERIVED}
${SECONDARY_TENANT_DOMAINS}
${GLOBAL_TENANT_DOMAIN}
${ARTIFACT_REPO_URL}
${PING_ARTIFACT_REPO_URL}
${LOG_ARCHIVE_URL}
${BACKUP_URL}
${PGO_BACKUP_BUCKET_NAME}
${PING_CLOUD_NAMESPACE}
${K8S_GIT_URL}
${K8S_GIT_BRANCH}
${ECR_REGISTRY_NAME}
${KNOWN_HOSTS_CLUSTER_STATE_REPO}
${CLUSTER_STATE_REPO_URL}
${CLUSTER_STATE_REPO_BRANCH}
${CLUSTER_STATE_REPO_PATH_DERIVED}
${SERVER_PROFILE_URL}
${SERVER_PROFILE_BRANCH_DERIVED}
${SERVER_PROFILE_PATH}
${ENV}
${ENVIRONMENT_TYPE}
${KUSTOMIZE_BASE}
${LETS_ENCRYPT_SERVER}
${USER_BASE_DN}
${USER_BASE_DN_2}
${USER_BASE_DN_3}
${USER_BASE_DN_4}
${USER_BASE_DN_5}
${ADMIN_CONSOLE_BRANDING}
${ENVIRONMENT_PREFIX}
${NEW_RELIC_ENVIRONMENT_NAME}
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
${MYSQL_SERVICE_HOST}
${MYSQL_USER}
${MYSQL_PASSWORD}
${MYSQL_DATABASE}
${CLUSTER_NAME}
${CLUSTER_NAME_LC}
${DNS_ZONE}
${DNS_ZONE_DERIVED}
${PRIMARY_DNS_ZONE}
${PRIMARY_DNS_ZONE_DERIVED}
${METADATA_IMAGE_TAG}
${BOOTSTRAP_IMAGE_TAG}
${P14C_INTEGRATION_IMAGE_TAG}
${ANSIBLE_BELUGA_IMAGE_TAG}
${PINGCENTRAL_IMAGE_TAG}
${PINGACCESS_IMAGE_TAG}
${PINGACCESS_WAS_IMAGE_TAG}
${PINGFEDERATE_IMAGE_TAG}
${PINGDIRECTORY_IMAGE_TAG}
${PINGDELEGATOR_IMAGE_TAG}
${PINGDATASYNC_IMAGE_TAG}
${IRSA_PING_ANNOTATION_KEY_VALUE}
${IRSA_PA_ANNOTATION_KEY_VALUE}
${IRSA_PD_ANNOTATION_KEY_VALUE}
${IRSA_PF_ANNOTATION_KEY_VALUE}
${NLB_NGX_PUBLIC_ANNOTATION_KEY_VALUE}
${DATASYNC_P1AS_SYNC_SERVER}
${LEGACY_LOGGING}
${ARGOCD_SLACK_TOKEN_BASE64}
${RADIUS_PROXY_ENABLED}
${PF_PROVISIONING_ENABLED}
${SLACK_CHANNEL}
${PROM_SLACK_CHANNEL}
${DASH_REPO_URL}
${DASH_REPO_BRANCH}'

########################################################################################################################
# Export some derived environment variables.
########################################################################################################################
add_derived_variables() {
  # The directory within the cluster state repo for the region's manifest files.
  export CLUSTER_STATE_REPO_PATH_DERIVED="\${REGION_NICK_NAME}"

  # Server profile branch. The directory is in each app's env_vars file.
  export SERVER_PROFILE_BRANCH_DERIVED="\${CLUSTER_STATE_REPO_BRANCH}"

  # Zone for this region and the primary region.
  export DNS_ZONE_DERIVED="\${DNS_ZONE}"
  export PRIMARY_DNS_ZONE_DERIVED="\${PRIMARY_DNS_ZONE}"

  # Zone for this region and the primary region.
  if "${IS_BELUGA_ENV:-false}" || test "${ENV}" = "${CUSTOMER_HUB}"; then
    export DNS_ZONE="\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${PRIMARY_TENANT_DOMAIN}"
  else
    export DNS_ZONE="\${REGION_ENV}-\${TENANT_DOMAIN}"
    export PRIMARY_DNS_ZONE="\${ENV}-\${PRIMARY_TENANT_DOMAIN}"
  fi

  export PRIMARY_TENANT_DOMAIN_DERIVED="\${PRIMARY_TENANT_DOMAIN}"

  # This variable's value will make it onto the branding for all admin consoles and
  # will include the name of the environment and the region where it's deployed.
  export ADMIN_CONSOLE_BRANDING="\${ENV}-\${REGION}"

  # This variable's value will be used as the prefix to distinguish between PF apps for different CDEs for a single
  # P14C tenant. All of these apps will be created within the "Administrators" environment in the tenant.
  export ENVIRONMENT_PREFIX="\${TENANT_NAME}-\${CLUSTER_STATE_REPO_BRANCH}-\${REGION_NICK_NAME}"

  # The name of the environment as it will appear on the NewRelic console.
  export NEW_RELIC_ENVIRONMENT_NAME="\${TENANT_NAME}_\${REGION_ENV}_\${REGION_NICK_NAME}_k8s-cluster"
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

    # Remove LAST_UPDATE_REASON because it can have spaces. The source will fail otherwise.
    sed -i.bak '/^LAST_UPDATE_REASON=.*$/d' "${env_file_bak}"
    rm -f "${env_file_bak}".bak

    set -a
    # shellcheck disable=SC1090
    source "${env_file_bak}"
    set +a

    rm -f "${env_file_bak}"
  fi
}

# Determine if macOS - oftentimes upgrades run on macOS but sometimes they run on other machines too
# Returns 0 if macOS, 1 otherwise
is_macos() {
  os=$(uname)
  if [[ "${os}" == *"Darwin"* ]]; then
    return 0
  else
    return 1
  fi
}

# Automatically set the base64 decode option based on OS
get_base64_decode_opt() {
  if is_macos; then
    echo "-d"
  else
    echo "-D"
  fi
}

########################################################################################################################
# Find the secrets.yaml and parse it for the given secret_key, then set the var_to_set to the value under the key
#
# Arguments
#   $1 secret_key -> The secret key to retrieve from the secrets.yaml
#   $2 var_to_set -> The variable to set with the value under secret_key from secrets.yaml
# Returns
#   The base64-decoded value of the secret, or empty if there is an error or the secret is not found.
#   Also returns non-zero on error.
########################################################################################################################
get_secret_from_yaml() {
  local secret_key="${1}"
  local var_to_set="${2}"
  local secret_value=""

  # Get the path of the secrets.yaml file that has all ping-cloud secrets.
  secrets_yaml="$(find . -name secrets.yaml -type f)"

  # If found, copy it to the provided output file in JSON format.
  if test "${secrets_yaml}"; then
    log "Attempting to retrieve ${secret_key} from ${secrets_yaml}"
    if ! secret_value="$(yq -r ".. | select(has(\"${secret_key}\")) | .[]" "${secrets_yaml}")"; then
      log "Unable to parse secret from file ${secrets_yaml}"
      return 1
    fi
    log "Found ${secret_key} in ${secrets_yaml}"
  else
    log "ping-cloud secrets.yaml file not found."
    return 1
  fi

  if ! secret_value=$(echo "${secret_value}" | base64 "${BASE64_DECODE_OPT}"); then
    log "Error decoding base64 secret"
    return 1
  fi

  # If the options were printed out for base64, there was an error (it doesn't exit nonzero on improper usage)
  if [[ "${secret_value}" == *"option"* ]]; then
    log "Error decoding base64 secret - invalid option passed"
    return 1
  fi

  log "Successfully decoded base64 secret"

  export "${var_to_set}=${secret_value}"
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
# Create .old secrets files for $all_secrets
# one. This makes it easier for the operator to see the differences in secrets between the two branches.
#
# Arguments
#   $1 -> The new branch for a default git branch.
########################################################################################################################
create_dot_old_files() {
  local update_branch="$1"
  local all_secrets=("${SECRETS_FILE_NAME}" "${ORIG_SECRETS_FILE_NAME}" "${SEALED_SECRETS_FILE_NAME}")

  log "Handling changes to ${all_secrets[*]} in branch '${OLD_BRANCH}'"

  # First switch to the old git branch.
  git checkout --quiet "${OLD_BRANCH}"
  old_secrets_dir="$(mktemp -d)"

  for old_secrets_file in "${all_secrets[@]}"; do
    log "Copying old ${old_secrets_file} in branch '${OLD_BRANCH}'"
    secret_path=$(find . -name "${old_secrets_file}" -type f)
    git show "${OLD_BRANCH}:${secret_path}" >> "${old_secrets_dir}/${old_secrets_file}"
  done

  # Switch to the new git branch and copy over the old secrets
  git checkout --quiet "${update_branch}"

  secret_files="$(find "${old_secrets_dir}" -type f)"
  for secret_path in ${secret_files}; do
    file_name="$(basename "${secret_path}")"
    dst_file="${K8S_CONFIGS_DIR}/${BASE_DIR}/${file_name}"
    cp "${secret_path}" "${dst_file}.old"
  done

  msg="Done creating .old files for ${all_secrets[*]}"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Copy new k8s-configs files from the default git branch into its new one.
#
# Arguments
#   $1 -> The new branch for a default git branch.
########################################################################################################################
handle_changed_k8s_configs() {
  local update_branch="$1"

  log "Handling non Beluga-owned files in branch '${OLD_BRANCH}'"

  log "Reconciling '${K8S_CONFIGS_DIR}' diffs between '${OLD_BRANCH}' and its new branch '${update_branch}'"
  git checkout --quiet "${update_branch}"
  new_files="$(git_diff "${OLD_BRANCH}" HEAD "${K8S_CONFIGS_DIR}")"

  if ! test "${new_files}"; then
    log "No changed '${K8S_CONFIGS_DIR}' files to copy '${OLD_BRANCH}' to its new branch '${update_branch}'"
  fi

  log "DEBUG: Found the following new files in branch '${OLD_BRANCH}':"
  echo "${new_files}"

  KUSTOMIZATION_FILE="${CUSTOM_RESOURCES_REL_DIR}/kustomization.yaml"
  KUSTOMIZATION_BAK_FILE="${KUSTOMIZATION_FILE}.bak"

  # Special-case the handling all files owned by PS/GSO.

  # 1. Copy the custom-patches.yaml file (owned by PS/GSO) as is.
  # 2. Copy the custom-resources/kustomization.yaml, which references the custom resources (also owned by PS/GSO) as is.
  # 3. Copy the ping-cloud/descriptor.json file (also owned by PS/GSO) as is.
  for file in ${CUSTOM_RESOURCES_REL_DIR}/kustomization.yaml \
              ${CUSTOM_PATCHES_REL_FILE_NAME} \
              ${PING_CLOUD_REL_DIR}/${DESCRIPTOR_JSON_FILE_NAME}; do
    if git show "${OLD_BRANCH}:${file}" &> /dev/null; then
      log "Copying file ${OLD_BRANCH}:${file} to the same location on ${update_branch}"
      git show "${OLD_BRANCH}:${file}" > "${file}"
    else
      log "${file} does not exist in default git branch ${OLD_BRANCH}"
    fi
  done

  for new_file in ${new_files}; do
    # Ignore Beluga-owned files.
    new_file_basename="$(basename "${new_file}")"
    if echo "${beluga_owned_k8s_files}" | grep -q "@${new_file_basename}"; then
      log "Ignoring file ${OLD_BRANCH}:${new_file} since it is a Beluga-owned file"
      continue
    fi

    # Copy files in the custom-resources section (owned by PS/GSO) as is.
    new_file_dirname="$(dirname "${new_file}")"
    if test "${new_file_dirname##*/}" = "${CUSTOM_RESOURCES_DIR}"; then
      log "Copying custom resource file ${OLD_BRANCH}:${new_file} to the same location on ${update_branch}"
      git show "${OLD_BRANCH}:${new_file}" > "${new_file}"
      continue
    fi

    # Copy non-YAML files (owned by PS/GSO) to the same location on the new branch, e.g. sealingkey.pem
    new_file_ext="${new_file_basename##*.}"
    if test "${new_file_ext}" != 'yaml'; then
      log "Copying non-YAML file ${OLD_BRANCH}:${new_file} to the same location on ${update_branch}"
      mkdir -p "${new_file_dirname}"
      git show "${OLD_BRANCH}:${new_file}" > "${new_file}"
      continue
    fi

    log "Copying custom file ${OLD_BRANCH}:${new_file} into directory ${CUSTOM_RESOURCES_REL_DIR}"
    git show "${OLD_BRANCH}:${new_file}" > "${CUSTOM_RESOURCES_REL_DIR}/${new_file_basename}"

    log "Adding new resource file ${new_file_basename} to ${KUSTOMIZATION_FILE}"
    new_resource_line="- ${new_file_basename}"

    grep_opts=(-q -e "${new_resource_line}")
    if ! grep "${grep_opts[@]}" "${KUSTOMIZATION_FILE}"; then
      # shellcheck disable=SC1003
      sed -i.bak -e '/^resources:$/a\'$'\n'"${new_resource_line}" "${KUSTOMIZATION_FILE}"
      rm -f "${KUSTOMIZATION_BAK_FILE}"
    fi
  done

  msg="Copied new '${K8S_CONFIGS_DIR}' files '${OLD_BRANCH}' to its new branch '${update_branch}'"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Prints a README containing next steps to take.
########################################################################################################################
print_readme() {
  echo
  echo '################################################################################'
  echo '#                                    README                                    #'
  echo '################################################################################'
  echo
  echo "- The following new git branches have been created for the default ones:"
  echo
  echo "${ENV_BRANCH_MAP}" | tr "${SEPARATOR}" '\n'
  echo
  echo "- No changes have been made to the default git branches."
  echo
  echo "- The new git branches are just local branches and not pushed to the server."
  echo "  They contain cluster state valid for '${NEW_VERSION}'."
  echo

  if "${RESET_TO_DEFAULT}"; then
    echo "- All environment variables have been reset to the default for '${NEW_VERSION}'."
  else
    echo "- Environment variables have been migrated to '${NEW_VERSION}' with the exception"
    echo "  of app JVM settings."
  fi
  echo
  echo "    - The '${ENV_VARS_FILE_NAME}' files have been copied over from the default git branch"
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

  if test -n "${ID_RSA_VALUE}"; then
    echo "- The git SSH key has been successfully moved to the '${NEW_VERSION}'."
  else
    echo "- The git SSH key in 'argo-git-deploy' and 'ssh-id-key-secret'"
    echo "  contain fake values and must be updated."
    echo
    echo "    - Reach out to the platform team to get the right values for these secrets."
  fi

  echo
  echo "- The '${SECRETS_FILE_NAME}', '${ORIG_SECRETS_FILE_NAME}' and '${SEALED_SECRETS_FILE_NAME}'"
  echo "  files have been copied over from the default git branch with a suffix of '.old',"
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
    echo "  migrated to the new git branches."
    echo
    echo "    - The following files in '${K8S_CONFIGS_DIR}' are typically customized:"
    echo
    echo "        - PingDirectory '${DESCRIPTOR_JSON_FILE_NAME}' for multi-region customers"
    echo "        - Additional custom certificates/ingresses or patches to existing ones"
    echo
    echo "    - To get a list of all '${K8S_CONFIGS_DIR}' files that are different"
    echo "      between a default git branch and its new branch, run:"
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
  echo "    - Verify that the generated manifest looks right for the environment and region."
  echo
  echo "    - Repeat the command for every region for multi-region customers."
  echo
  echo "    - Pay special attention to app JVM settings and ensure that they are"
  echo "      adequate for the type and size of the environment. Reach out to the"
  echo "      Beluga team on sizing guidance."
  echo

  echo "- After verifying the generated manifest, rename the default git branches to"
  echo "  backup branches:"
  echo
  echo "      git checkout <default-cde-branch>"
  echo "      git branch -m <old-version>-<default-cde-branch>"
  echo
  echo "- Rename the new git branches to their corresponding default branch name:"
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
  echo "- Push the newly migrated git branches to the server."
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
check_binaries 'kubectl' 'git' 'base64' 'jq' 'envsubst' 'rsync' 'yq' || exit 1

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

if test -n "$(git status -s)"; then
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
  echo '    git clean -fd             # Get rid of untracked files and directories'
  echo

  exit 1
fi

AUTO_BASE64_DECODE_OPT=$(get_base64_decode_opt)
BASE64_DECODE_OPT="${BASE64_DECODE_OPT:-${AUTO_BASE64_DECODE_OPT}}"

# Save off the current branch so we can switch back to it at the end of the script.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Validate that a git branch exists for every environment.
ALL_ENVIRONMENTS='dev test stage prod customer-hub'
ENVIRONMENTS="${ENVIRONMENTS:-${ALL_ENVIRONMENTS}}"

NEW_BRANCHES=
REPO_STATUS=0

for ENV in ${ENVIRONMENTS}; do
  test "${ENV}" = 'prod' &&
      OLD_BRANCH='master' ||
      OLD_BRANCH="${ENV}"

  log "Validating that '${CLUSTER_STATE_REPO}' has branch: '${OLD_BRANCH}'"
  git checkout --quiet "${OLD_BRANCH}"
  if test $? -ne 0; then
    log "git branch '${OLD_BRANCH}' does not exist in '${CLUSTER_STATE_REPO}'"
    REPO_STATUS=1
  fi

  NEW_BRANCH="${NEW_VERSION}-${OLD_BRANCH}"
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

# Get existing SSH key from secrets.yaml for upgraded secrets.yaml and place into a file for generate-cluster-state.sh
get_secret_from_yaml "id_rsa" "ID_RSA_VALUE"
ID_RSA_FILE=""
if [[ -n "${ID_RSA_VALUE}" ]]; then
  ID_RSA_FILE=$(mktemp)
  echo "${ID_RSA_VALUE}" > "${ID_RSA_FILE}"
fi

# For each environment:
#   - Generate code for all its regions
#   - Push code for all its regions into new branches
for ENV in ${ENVIRONMENTS}; do # ENV loop
  test "${ENV}" = 'prod' &&
      OLD_BRANCH='master' ||
      OLD_BRANCH="${ENV}"

  if echo "${ENV}" | grep -q "${CUSTOMER_HUB}"; then
    IS_CUSTOMER_HUB=true
  else
    IS_CUSTOMER_HUB=false
  fi

  NEW_BRANCH="${NEW_VERSION}-${OLD_BRANCH}"
  log "Updating branch '${NEW_BRANCH}' for environment '${ENV}'"

  log "Switching to branch ${OLD_BRANCH} to determine deployed regions"
  git checkout --quiet "${OLD_BRANCH}"

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

        export ARGOCD_SLACK_TOKEN_SSM_PATH="${ARGOCD_SLACK_TOKEN_SSM_PATH}"

        # If customer-hub branch, reset the LETS_ENCRYPT_SERVER so the prod one is set by default.
        if "${IS_CUSTOMER_HUB}"; then
          log "Unsetting LETS_ENCRYPT_SERVER for the ${CUSTOMER_HUB} branch"
          unset LETS_ENCRYPT_SERVER
        fi

        log "Using LETS_ENCRYPT_SERVER: ${LETS_ENCRYPT_SERVER}"

        # Also set SERVER_PROFILE_URL to empty so the new default (i.e. profile-repo with the same URL as the CSR)
        # is automatically used.

        # Last but not least, set the PING_IDENTITY_DEVOPS_USER/KEY to empty so they are fetched from SSM going forward.
        # Also set the MYSQL_USER/PASSWORD to empty so they are fetched from AWS Secrets Manager going forward.
        set -x
        QUIET=true \
            TARGET_DIR="${TARGET_DIR}" \
            SERVER_PROFILE_URL='' \
            K8S_GIT_URL="${PING_CLOUD_BASE_REPO_URL}" \
            K8S_GIT_BRANCH="${NEW_VERSION}" \
            ENVIRONMENTS="${NEW_BRANCH}" \
            PING_IDENTITY_DEVOPS_USER='' \
            PING_IDENTITY_DEVOPS_KEY='' \
            MYSQL_USER='' \
            MYSQL_PASSWORD='' \
            PLATFORM_EVENT_QUEUE_NAME='' \
            SSH_ID_PUB_FILE='' \
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

      # Import new env_vars into cluster-state-repo and rename original env_vars as env_vars.old.
      ENV_VARS_FILES="$(find "${TARGET_DIR}" -name "${ENV_VARS_FILE_NAME}" -type f)"

      # Add some derived environment variables for substitution.
      add_derived_variables

      for TEMPLATE_ENV_VARS_FILE in ${ENV_VARS_FILES}; do # Loop through env_vars from ping-cloud-base/code-gen

        DIR_NAME="$(dirname "${TEMPLATE_ENV_VARS_FILE}")"
        PARENT_DIR_NAME="$(dirname "${DIR_NAME}")"

        DIR_NAME="${DIR_NAME##*/}"
        PARENT_DIR_NAME="${PARENT_DIR_NAME##*/}"

        if test "${DIR_NAME}" = "${BASE_DIR}"; then
          # Capture original env_var for primary or customer-hub region only.
          if "${IS_PRIMARY}" = "true" || "${IS_CUSTOMER_HUB}" = "true"; then
            ORIG_ENV_VARS_FILE="${BASE_ENV_VARS}"
          else
            # skip to next iteration when its secondary-region.
            continue
          fi
        elif test "${DIR_NAME}" = "${REGION_DIR}"; then
          ORIG_ENV_VARS_FILE="${REGION_ENV_VARS}"
        else
          # Capture original env_var for ping app-specific directory.
          if echo "${DIR_NAME}" | grep -q 'ping'; then
             ORIG_ENV_VARS_FILE="${K8S_CONFIGS_DIR}/${REGION_DIR}/${DIR_NAME}/${ENV_VARS_FILE_NAME}"
          elif test "${DIR_NAME}" = 'admin' || test "${DIR_NAME}" = 'engine'; then
             ORIG_ENV_VARS_FILE="${K8S_CONFIGS_DIR}/${REGION_DIR}/${PARENT_DIR_NAME}/${DIR_NAME}/${ENV_VARS_FILE_NAME}"
          else
            log "Not an app-specific env_vars file: ${TEMPLATE_ENV_VARS_FILE}"
            # skip to next iteration.
            continue
          fi
        fi

        # Backup original env_vars by generating env_vars.old file.
        OLD_ENV_VARS_FILE="$(dirname "${TEMPLATE_ENV_VARS_FILE}")/${ENV_VARS_FILE_NAME}".old
        log "Backing up '${ORIG_ENV_VARS_FILE}' for region '${REGION_DIR}' and branch '${NEW_BRANCH}'"
        cp -f "${ORIG_ENV_VARS_FILE}" "${OLD_ENV_VARS_FILE}"

        # Substitute variables into new imported env_vars.
        tmp_file=$(mktemp)
        envsubst "${ENV_VARS_TO_SUBST}" < "${TEMPLATE_ENV_VARS_FILE}" > "${tmp_file}"
        mv "${tmp_file}" "${TEMPLATE_ENV_VARS_FILE}"

        # If there are no differences between env_vars and env_vars.old, delete the old one.
        if diff -qbB "${TEMPLATE_ENV_VARS_FILE}" "${OLD_ENV_VARS_FILE}"; then
          log "No difference found between ${TEMPLATE_ENV_VARS_FILE} and ${OLD_ENV_VARS_FILE} - removing the old one"
          rm -f "${OLD_ENV_VARS_FILE}"
        else
          log "Difference found between ${TEMPLATE_ENV_VARS_FILE} and ${OLD_ENV_VARS_FILE} - keeping the old one"
        fi

      done # Loop for env_vars
    )
  done # REGION loop for generate

  # Determine the primary region. If we can't, then error out.
  PRIMARY_REGION_DIR="$(cat "${PRIMARY_REGION_DIR_FILE}")"
  if test "${PRIMARY_REGION_DIR}"; then
    log "Primary region directory for '${ENV}': '${PRIMARY_REGION_DIR}'"
  elif "${IS_CUSTOMER_HUB}"; then
    log "Primary region not found for '${ENV}'. Will default to first region found."
  else
    log "Primary region is unknown for '${ENV}'"
    exit 1
  fi

  # Sort the regions such that the primary region is first in order.
  REGION_DIRS_SORTED="${PRIMARY_REGION_DIR}"
  for REGION_DIR in ${REGION_DIRS}; do # REGION sort loop
    # If primary region not set and it's the customer-hub branch, then default it to the first region.
    if test ! "${PRIMARY_REGION_DIR}" && "${IS_CUSTOMER_HUB}"; then
      PRIMARY_REGION_DIR="${REGION_DIR}"
      REGION_DIRS_SORTED="${PRIMARY_REGION_DIR}"
      log "Defaulting primary region to '${ENV}' to: '${PRIMARY_REGION_DIR}'."
    fi
    if test "${PRIMARY_REGION_DIR}" != "${REGION_DIR}"; then
      REGION_DIRS_SORTED="${REGION_DIRS_SORTED} ${REGION_DIR}"
    fi
  done # REGION sort loop

  log "Region directories in sorted order for '${ENV}': ${REGION_DIRS_SORTED}"
  for REGION_DIR in ${REGION_DIRS_SORTED}; do # REGION loop for push
    if test "${PRIMARY_REGION_DIR}" = "${REGION_DIR}"; then
      IS_PRIMARY=true
      TYPE='primary'
    else
      IS_PRIMARY=false
      TYPE='secondary'
    fi

    if "${IS_CUSTOMER_HUB}" && ! "${IS_PRIMARY}"; then
      log "Not pushing '${CUSTOMER_HUB}' branch for secondary region"
      continue
    fi

    TARGET_DIR="${TENANT_CODE_DIR}/${REGION_DIR}"
    log "Generated code directory for ${TYPE} region '${REGION_DIR}' and '${ENV}': ${TARGET_DIR}"

    log "Creating branch for ${TYPE} region '${REGION_DIR}' and '${ENV}': ${NEW_BRANCH}"
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
      log "Error creating branch '${NEW_BRANCH}' for ${TYPE} region '${REGION_DIR}' and '${ENV}': ${PUSH_RC}"
      exit ${PUSH_RC}
    fi
    log "Done creating branch '${NEW_BRANCH}' for ${TYPE} region '${REGION_DIR}' and '${ENV}'"

  done # REGION loop for push

  # Create .old files for secrets files so it's easy to see the differences in a pinch.
  create_dot_old_files "${NEW_BRANCH}" "${PRIMARY_REGION_DIR}"

  # If requested, copy new k8s-configs files from the default git branches into their corresponding new branches.
  if "${RESET_TO_DEFAULT}"; then
    log "Not migrating '${K8S_CONFIGS_DIR}' because migration was explicitly skipped"
  else
    handle_changed_k8s_configs "${NEW_BRANCH}"
  fi

  log "Done updating branch '${NEW_BRANCH}' for '${ENV}'"

  # Keep track of branches for the README
  BRANCH_LINE="${TAB}${NEW_BRANCH} -> ${OLD_BRANCH}" 
  if test "${ENV_BRANCH_MAP}"; then
    ENV_BRANCH_MAP="${ENV_BRANCH_MAP}${SEPARATOR}${BRANCH_LINE}"
  else
    ENV_BRANCH_MAP="${BRANCH_LINE}"
  fi
done # ENV loop

# Print a README of next steps to take.
print_readme
