#!/usr/bin/env sh
. "${HOOKS_DIR}/utils.lib.sh" > /dev/null

delete_file() {
  local file=${1}
  beluga_log "Checking for ${file}"
  if test -f "${file}"; then
    rm -f "${file}"
    if test $? -eq 0; then
      beluga_log "Successfully deleted ${file}"
    else
      beluga_error "Failed to delete ${file}"
    fi
  else
    beluga_log "${file} not found"
  fi
}


# PDO-2236 - Look for 30-daily-encrypted-export.dsconfig and remove it if it's found
delete_file '/opt/staging/pd.profile/dsconfig/30-daily-encrypted-export.dsconfig'
