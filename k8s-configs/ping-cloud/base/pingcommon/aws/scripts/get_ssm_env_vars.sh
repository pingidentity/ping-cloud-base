#!/bin/sh

VERBOSE="${VERBOSE:-false}"

# Configuration file to share environment variables with main container.
CONFIG_FILE='/config/ds_env_vars'

# Enable debug flag for aws cli if VERBOSE is true
if "${VERBOSE}"; then
  AWS_DEBUG='--debug'
fi

# Verify that the mandatory variable is set.
if test -z "${REGION}"; then
  echo "REGION environment variable must be set"
  exit 1
fi

echo "AWSCLI VERSON: $(aws --version)"
echo "AWS_REGION: ${REGION}"

# Query aws endpoint to get value associated with the key.
get_ssm_val() {
  param_name="$1"
  if ! ssm_val="$(aws ${AWS_DEBUG} ssm --region "${REGION}" get-parameters \
            --names "${param_name%#*}" \
            --query 'Parameters[*].Value' \
            --with-decryption \
            --output text)"; then
    echo "$ssm_val"
    return 1
  fi
  if [[ "$param_name" == *"secretsmanager"* ]]; then
    # grep for the value of the secrets manager object's key
    # the object's key is the string following the '#' in the param_name variable
    # Using python 2.7 available in docker image to retrieve JSON value.
    # Retrieved value should not contain any special characters so quoting is not required.
    echo "$ssm_val" | python -c "import sys, json; print json.load(sys.stdin)['${param_name#*#}']"
  else
    echo "$ssm_val"
  fi
}

# Check all the environment variables
get_ssm_key() {
  for i in $(printenv); do
    key=${i%=*}
    val=${i#*=}
    case "$val" in "ssm://"*)
      if ! ssm_rv=$(get_ssm_val "${val#ssm:/}"); then
        return 1
      fi
      echo "$key=$ssm_rv" >>"${CONFIG_FILE}"
    esac
  done
}

echo "# Start Discovery Service" >>"${CONFIG_FILE}"

if ! get_ssm_key; then
  exit 1
fi

echo "# End Discovery Service" >>"${CONFIG_FILE}"

exit 0
