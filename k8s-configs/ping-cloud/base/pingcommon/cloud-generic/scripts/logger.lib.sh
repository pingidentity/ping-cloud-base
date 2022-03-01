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

########################################################################################################################
# Logs the provided message and set the log level to ERROR.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
beluga_error() {
  beluga_log "$1" 'ERROR'
}

########################################################################################################################
# Logs the provided message and set the log level to WARN.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
beluga_warn() {
  beluga_log "$1" 'WARN'
}

########################################################################################################################
# Logs the provided message and set the log level to DEBUG.
#
# Arguments
#   $1 -> The log message.
########################################################################################################################
beluga_debug() {
  beluga_log "$1" 'DEBUG'
}
