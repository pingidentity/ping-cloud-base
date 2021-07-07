#!/usr/bin/env sh

. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

beluga_log "Uploading to location ${LOG_ARCHIVE_URL}"

# Set required environment variables for skbn
initializeSkbnConfiguration "${LOG_ARCHIVE_URL}"

if ! cd "${OUT_DIR}"; then 
  beluga_log "Failed to chdir: ${OUT_DIR}"
  exit 1
fi

# PDO-1812 - Inspect the filesystem for orphaned zip files from previous runs
existing_zips=$(find "${SERVER_ROOT_DIR}/bin/" -name "*support-data.zip")
if ! test -z "${existing_zips}"; then
  beluga_log "Found these orphaned zip files from previous runs:" "WARN"
  for entry in ${existing_zips}
  do
    beluga_log "$entry" "WARN"
  done
fi

# pdo-1388 - Specify the generated zip file to be in the format:
#
#  YYYYMMDDHHMM-<pod name>-support-data.zip
#
support_data_filename="$(date +"%Y%m%d%H%M")-$(hostname)-support-data.zip"
support_data_file_path="${SERVER_ROOT_DIR}/bin/${support_data_filename}"

# Calling collect-support-data.sh to produce a zip of diagnostic info is pretty straightforward.
# However, unit testing this script via shunit2 is a bit trickier.  First, collect-support-data.sh
# doesn't exist on the test machine.  It's put onto the filesystem at runtime.  Consequently,
# when the unit tests run, the shell can't resolve the path to the script and so it exits
# immediately with a 'command not found' error before the test can finish.  Attempts to isolate
# the call in a util script and mock around via in the test didn't work.  The hacky workaround
# is to assign the full command to an alias and then mock the alias in the test.
beluga_log "Executing script: ${SERVER_ROOT_DIR}/bin/collect-support-data.sh --outputPath=${support_data_file_path}"
alias collect-data="${SERVER_ROOT_DIR}/bin/collect-support-data.sh --outputPath=${support_data_file_path}"

# Execute in a subshell to remove the collect-support-data.sh script output from normal logging.
# That output will now only be displayed if there's an error.
collect_support_data_output=$(collect-data)
collect_support_data_return_code=$?
unalias collect-data

if test ${collect_support_data_return_code} -ne 0; then
  printf "$collect_support_data_output"
  echo "Failed to execute:  ${SERVER_ROOT_DIR}/bin/collect-support-data.sh"
  echo "Return code was: ${collect_support_data_return_code}"
  exit 1
fi

zip_file=$(find "${SERVER_ROOT_DIR}/bin/" -name "${support_data_filename}" -type f | sort | tail -1)
if test -z "${zip_file}"; then
  beluga_log "Unable to find the support-data zip file here: ${SERVER_ROOT_DIR}/bin/${support_data_filename}.  Disregard this message if the pod is not up yet." "WARN"
  exit 1
else
  support_data_size=$(stat -c %s "${support_data_file_path}")
  if test ${support_data_size} -eq 0; then
    beluga_log "The support-data zip file size was 0 bytes.  Disregard this message if the pod is not up yet." "WARN"
    exit 1
  fi
fi

if ! test -z "${support_data_file_path}"; then

  # Use the absolute path to the generated zip file
  src_file="${support_data_file_path}"

  beluga_log "Copying: ${src_file} to ${SKBN_CLOUD_PREFIX}/${support_data_filename}"

  # Copy the generated zip file to the s3 bucket and rename it
  if ! skbnCopy "${src_file}" "${SKBN_CLOUD_PREFIX}/${support_data_filename}"; then
      exit 1
  fi

  # Remove the CSD file so it is doesn't fill up the server's filesystem.
  beluga_log "Removing: ${support_data_file_path}"
  rm -f "${support_data_file_path}"

  if test $? -eq 0; then
    beluga_log "${support_data_file_path} removed successfully"
  else
    beluga_log "There was a problem removing ${support_data_file_path}.  Remove exiting with: $?" "ERROR"
    exit 1
  fi

  # Print the filename so callers can figure out the name of the CSD file that was uploaded.
  echo ${support_data_filename}
else
  beluga_log "There was a problem finding the generated support data file here: ${support_data_file_path}." "WARN"
  beluga_log "The file name is expected to be in the format: YYYYMMDDHHMM-<pod name>-support-data.zip" "WARN"
  beluga_log "Exiting with a 1"

  exit 1
fi
