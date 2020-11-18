#!/bin/bash

########################################################################################################################
# Retrieve and return SSM parameter value.
#
# Arguments
#   $1 -> SSM key path
########################################################################################################################
get_ssm_value() {
  local ssm_key="$1"

  if ! ssm_value="$(aws ssm --region "${REGION}"  get-parameters \
    --names "$ssm_key" \
    --query 'Parameters[*].Value' \
    --output text)"; then
      echo "$ssm_value"
      return 1
  fi

  if test -z "${ssm_value}"; then
    echo "Unable to find SSM path '${ssm_key}'"
    return 1
  else
    echo "${ssm_value}"
  fi
}
