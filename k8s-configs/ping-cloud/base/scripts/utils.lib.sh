#!/usr/bin/env sh

########################################################################################################################
# Logs the provided message at the provided log level. Default log level is INFO, if not provided.
#
# Arguments
#   $1 -> The log message.
#   $2 -> Optional log level. Default is INFO.
########################################################################################################################
beluga_log() {
  file_name="$(basename "$0")"
  message="$1"
  test -z "$2" && log_level='INFO' || log_level="$2"

  format='+%Y-%m-%d %H:%M:%S'
  timestamp="$(TZ=UTC date "${format}")"

  echo "${file_name}: ${timestamp} ${log_level} ${message}"
}

PA_ADMIN_SERVER_NAME=pingaccess-admin-0
PA_ADMIN_SERVICE_NAME=pingaccess-admin
PA_ADMIN_WAIT_PORT=9000

PA_WAS_ADMIN_SERVER_NAME=pingaccess-was-admin-0
PA_WAS_ADMIN_SERVICE_NAME=pingaccess-was-admin
PA_WAS_ADMIN_WAIT_PORT=9000

PF_ADMIN_SERVER_NAME=pingfederate-admin-0
PF_ADMIN_SERVICE_NAME=pingfederate-admin
PF_ADMIN_WAIT_PORT=9999

PD_ADMIN_SERVER_NAME=pingdirectory-0
PD_ADMIN_SERVICE_NAME=pingdirectory
PD_ADMIN_WAIT_PORT=1636