#!/usr/bin/env sh

# Set default verbose level for deploy logs
VERBOSITY=${VERBOSITY:-3}

ERR_LVL=1
WRN_LVL=2
INF_LVL=3
DBG_LVL=4

########################################################################################################################
# Logs the provided message at the provided log level. Default log level is INFO, if not provided.
#
# Arguments
#   $1 -> The log message.
#   $2 -> Optional log level. Default is INFO.
########################################################################################################################
beluga_log() {
  VERBOSITY=$(echo "${VERBOSITY}" | tr '[:upper:]' '[:lower:]')
  case ${VERBOSITY} in
    [1-4]) ;;
    debug) VERBOSITY=4 ;;
    info) VERBOSITY=3 ;;
    warn) VERBOSITY=2 ;;
    error) VERBOSITY=1 ;;
    *) echo "Use number (1-4) or string (debug, info, warn, error) in VERBOSITY variable. Value: '${VERBOSITY}'" ; exit 1 ;;
  esac

  file_name="$(basename "$0")"
  message="$1"
  log_level="${2:-INFO}"
  case ${log_level} in
  DEBUG)
    verb_lvl=${DBG_LVL}
    ;;
  WARN)
    verb_lvl=${WRN_LVL}
    ;;
  ERROR)
    verb_lvl=${ERR_LVL}
    ;;
  *)
    verb_lvl=${INF_LVL}
    ;;
  esac
  format='+%Y-%m-%d %H:%M:%S'
  timestamp="$(TZ=UTC date "${format}")"
  if [ "${VERBOSITY}" -ge "${verb_lvl}" ]; then
    echo "${file_name}: ${timestamp} ${log_level} ${message}"
  fi
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
