#!/bin/bash

########################################################################################################################
# Retrieve and return SSM parameter or AWS Secrets value.
#
# Arguments
#   $1 -> SSM key path
#
#  Returns
#   0 on success; 1 if the aws ssm call fails or the key does not exist.
########################################################################################################################
get_ssm_value() {
  local ssm_key="$1"

  if ! ssm_value="$(aws ssm --region "${REGION}"  get-parameters \
    --names "${ssm_key%#*}" \
    --query 'Parameters[*].Value' \
    --with-decryption \
    --output text)"; then
      echo "$ssm_value"
      return 1
  fi

  if test -z "${ssm_value}"; then
    echo "Unable to find SSM path '${ssm_key%#*}'"
    return 1
  fi

  if [[ "$ssm_key" == *"secretsmanager"* ]]; then
    # grep for the value of the secrets manager object's key
    # the object's key is the string following the '#' in the ssm_key variable
    echo "${ssm_value}" | grep -Eo "${ssm_key#*#}[^,]*" | grep -Eo "[^:]*$"
  else
    echo "${ssm_value}"
  fi
}
