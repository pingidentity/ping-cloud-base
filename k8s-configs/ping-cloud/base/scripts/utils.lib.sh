#!/usr/bin/env sh

########################################################################################################################
# Standard log function.
#
########################################################################################################################
beluga_log()
{
  log_level="INFO"
  test ! -z "${2}" && log_level="${2}"
  format="+%Y-%m-%d:%Hh:%Mm:%Ss" # yyyy-mm-dd:00h:00m:00s
  timestamp=$( date "${format}" )
  message="${1}"
  file_name=$(basename "${0}")
  if [ "${log_level}" = "INFO" ];then
        echo "${timestamp} ${file_name}: ${message}"
  else
        echo "${log_level}: ${message}"
  fi
}