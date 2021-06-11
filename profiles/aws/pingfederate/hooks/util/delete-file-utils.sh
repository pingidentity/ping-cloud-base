#!/usr/bin/env sh

function delete_file() {
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
