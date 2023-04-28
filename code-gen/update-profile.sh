#!/bin/bash

# If VERBOSE is true, then output line-by-line execution
"${VERBOSE:-false}" && set -x

# This script may be used to upgrade an existing profile repo. It is designed to be non-destructive in that it
# won't push any changes to the server. Instead, it will set up a parallel branch for every CDE branch and/or the
# customer-hub branch as specified through the SUPPORTED_ENVIRONMENT_TYPES environment variable. For example, if the
# new version is v1.11.0 and the SUPPORTED_ENVIRONMENT_TYPES variable override is not provided, then it’ll set up 4 new
# CDE branches at the new version for the default set of environments: v1.11.0-dev, v1.11.0-test, v1.11.0-stage and
# v1.11.0-master and 1 new customer-hub branch v1.11.0-customer-hub.

# NOTE: The script must be run from the root of the profile repo clone directory. It acts on the following
# environment variables.
#
#   NEW_VERSION -> Required. The new version of Beluga to which to update the profile repo.
#   SUPPORTED_ENVIRONMENT_TYPES -> A space-separated list of environments. Defaults to 'dev test stage prod customer-hub',
#       if unset. If provided, it must contain all or a subset of the environments currently created by the
#       generate-cluster-state.sh script, i.e. dev, test, stage, prod and customer-hub.
#   RESET_TO_DEFAULT -> An optional flag, which if set to true will reset the profile repo to the OOTB state
#       for the new version. This has the same effect as running the platform code build job that initially seeds the
#       profile repo.

### Global values and utility functions ###
PROFILES_DIR='profiles'
CODE_GEN_DIR='code-gen'

ARTIFACTS_JSON_FILE_NAME='artifact-list.json'

PROFILE_REPO='profile-repo'
CUSTOMER_HUB='customer-hub'

PING_CLOUD_BASE='ping-cloud-base'

# If true, reset to the OOTB profile state for the new version, i.e. perform no migration.
RESET_TO_DEFAULT="${RESET_TO_DEFAULT:-false}"

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
  if echo "${NEW_BRANCH}" | grep -q "${CUSTOMER_HUB}"; then
    DEFAULT_GIT_BRANCH="${CUSTOMER_HUB}"
  else
    DEFAULT_GIT_BRANCH="${NEW_BRANCH##*-}"
  fi

  log "Reconciling '${PROFILES_DIR}' diffs between '${DEFAULT_GIT_BRANCH}' and its new branch '${NEW_BRANCH}'"

  git checkout --quiet "${NEW_BRANCH}"
  new_files="$(git_diff "${DEFAULT_GIT_BRANCH}" HEAD "${PROFILES_DIR}")"

  if ! test "${new_files}"; then
    log "No changed '${PROFILES_DIR}' files to copy '${DEFAULT_GIT_BRANCH}' to its new branch '${NEW_BRANCH}'"
  else
    log "DEBUG: Found the following new files in branch '${DEFAULT_GIT_BRANCH}':"
    echo "${new_files}"
    echo "${new_files}" | xargs git checkout "${DEFAULT_GIT_BRANCH}"
  fi

  # Copy artifact-list.json files from the default CDE branch into the new branch but with a .old extension.
  artifact_json_files="$(find "${PROFILES_DIR}" -name ${ARTIFACTS_JSON_FILE_NAME})"
  log "Found the following ${ARTIFACTS_JSON_FILE_NAME} files: ${artifact_json_files}"

  for artifact_file in ${artifact_json_files}; do
    log "Copying file ${DEFAULT_GIT_BRANCH}:${artifact_file} to the same location on ${NEW_BRANCH} with .old extension"
    git show "${DEFAULT_GIT_BRANCH}:${artifact_file}" > "${artifact_file}".old
  done

  msg="Copied changed '${PROFILES_DIR}' files from '${DEFAULT_GIT_BRANCH}' to its new branch '${NEW_BRANCH}'"
  log "${msg}"

  git add .
  git commit --allow-empty -m "${msg}"
}

########################################################################################################################
# Copy custom non-profiles files as is from old to new branch (including dot files).
#
# Arguments
#   $1 -> The new branch for a default CDE branch.
########################################################################################################################
handle_custom_files() {
  NEW_BRANCH="$1"
  if echo "${NEW_BRANCH}" | grep -q "${CUSTOMER_HUB}"; then
    DEFAULT_GIT_BRANCH="${CUSTOMER_HUB}"
  else
    DEFAULT_GIT_BRANCH="${NEW_BRANCH##*-}"
  fi

  git checkout --quiet "${DEFAULT_GIT_BRANCH}"
  custom_files="$(git ls-files | grep -v "^${PROFILES_DIR}" |
      grep -v 'update-profile-wrapper.sh' |
      grep -v 'version.txt')"

  if "${VERBOSE}" || "${DEBUG:-false}"; then
    log "DEBUG: Found the following custom non-profile files in branch '${DEFAULT_GIT_BRANCH}':"
    echo "${custom_files}"
  fi

  log "Copying custom non-profile files from '${DEFAULT_GIT_BRANCH}' to its new branch '${NEW_BRANCH}'"
  git checkout --quiet "${NEW_BRANCH}"
  echo "${custom_files}" | xargs git checkout "${DEFAULT_GIT_BRANCH}"

  msg="Copied custom non-profile files from '${DEFAULT_GIT_BRANCH}' to its new branch '${NEW_BRANCH}'"
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
    if echo "${NEW_BRANCH}" | grep -q "${CUSTOMER_HUB}"; then
      ENV="${CUSTOMER_HUB}"
    else
      ENV="${NEW_BRANCH##*-}"
    fi
    BRANCH_LINE="${TAB} ${NEW_BRANCH} -> ${ENV}"
    test "${ENV_BRANCH_MAP}" &&
        ENV_BRANCH_MAP="${ENV_BRANCH_MAP}${SEPARATOR}${BRANCH_LINE}" ||
        ENV_BRANCH_MAP="${BRANCH_LINE}"
  done

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
  echo "  They contain profiles valid for '${NEW_VERSION}'."
  echo
  echo "- After verifying the new branch, rename the default git branches to"
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
    echo 'for support with updating the profile-repo'
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
check_binaries 'git' || exit 1

# Verify that required environment variable NEW_VERSION is set.
if test -z "${NEW_VERSION}"; then
  log 'NEW_VERSION environment variable must be set before invoking this script'
  exit 1
fi

# Perform some basic validation of the profile repo.
if test ! -d "${PROFILES_DIR}"; then
  log 'Copy this script to the base directory of the profile repo and run it from there'
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

# Save off the current branch so we can switch back to it at the end of the script.
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Validate that a git branch exists for every environment.
ALL_ENVIRONMENTS='dev test stage prod customer-hub'
SUPPORTED_ENVIRONMENT_TYPES="${SUPPORTED_ENVIRONMENT_TYPES:-${ALL_ENVIRONMENTS}}"

NEW_BRANCHES=
REPO_STATUS=0

for ENV in ${SUPPORTED_ENVIRONMENT_TYPES}; do
  test "${ENV}" = 'prod' &&
      DEFAULT_GIT_BRANCH='master' ||
      DEFAULT_GIT_BRANCH="${ENV}"

  log "Validating that '${PROFILE_REPO}' has branch: '${DEFAULT_GIT_BRANCH}'"
  git checkout --quiet "${DEFAULT_GIT_BRANCH}"
  if test $? -ne 0; then
    log "git branch '${DEFAULT_GIT_BRANCH}' does not exist in '${PROFILE_REPO}'"
    REPO_STATUS=1
  fi

  NEW_BRANCH="${NEW_VERSION}-${DEFAULT_GIT_BRANCH}"
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

# Generate profile code for new version.

# NOTE: This entire block of code is being run from the profile-repo directory. All non-absolute paths are
# relative to this directory.

# Generate code for each new branch into a sandbox directory
# Push code for just the primary region into new branches

# Code for all environments will be generated in sub-directories of the following directory.
TEMP_DIR="$(mktemp -d)"

for ENV in ${SUPPORTED_ENVIRONMENT_TYPES}; do # ENV loop
  test "${ENV}" = 'prod' &&
      DEFAULT_GIT_BRANCH='master' ||
      DEFAULT_GIT_BRANCH="${ENV}"

  NEW_BRANCH="${NEW_VERSION}-${DEFAULT_GIT_BRANCH}"
  TARGET_DIR="${TEMP_DIR}/${NEW_BRANCH}"

  # Perform the code generation in a sub-shell so it doesn't pollute the current shell with environment variables.
  (
    log "Generating code into '${TARGET_DIR}'"
    QUIET=true \
        TARGET_DIR="${TARGET_DIR}" \
        SUPPORTED_ENVIRONMENT_TYPES="${NEW_BRANCH}" \
        "${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR}/generate-cluster-state.sh"

    GEN_RC=$?
    if test ${GEN_RC} -ne 0; then
      log "Error generating code: ${GEN_RC}"
      exit ${GEN_RC}
    fi
    log "Done generating code into '${TARGET_DIR}'"
  )

  log "Creating branch '${ENV}': ${NEW_BRANCH}"
  QUIET=true \
      GENERATED_CODE_DIR="${TARGET_DIR}" \
      IS_PRIMARY=true \
      IS_PROFILE_REPO=true \
      SUPPORTED_ENVIRONMENT_TYPES="${NEW_BRANCH}" \
      PUSH_TO_SERVER=false \
      "${NEW_PING_CLOUD_BASE_REPO}/${CODE_GEN_DIR}/push-cluster-state.sh"

  PUSH_RC=$?
  if test ${PUSH_RC} -ne 0; then
    log "Error creating branch '${NEW_BRANCH}' for '${ENV}': ${PUSH_RC}"
    exit ${PUSH_RC}
  fi
  log "Done creating branch '${NEW_BRANCH}' for '${ENV}'"

  # If requested, copy profiles files that were deleted or renamed from the default CDE branch into its new branch.
  if "${RESET_TO_DEFAULT}"; then
    log "Not migrating '${PROFILES_DIR}' because migration was explicitly skipped"
  else
    handle_changed_profiles "${NEW_BRANCH}"
    handle_custom_files "${NEW_BRANCH}"
  fi

  log "Done updating branch '${NEW_BRANCH}' for '${ENV}'"
done # ENV loop

# Print a README of next steps to take.
print_readme