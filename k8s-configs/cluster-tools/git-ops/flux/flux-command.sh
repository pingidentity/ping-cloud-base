#!/bin/sh

########################################################################################################################
# Substitute variables in all files in the provided directory with the values provided through the environments file.
#
# Arguments
#   $1 -> The file containing the environment variables to substitute.
#   $2 -> The directory that contains the files where variables must be substituted.
########################################################################################################################
substitute_vars() {
  env_file="$1"
  if test ! -f "${env_file}"; then
    echo "flux-command: env_file '${env_file}' does not exist"
    return
  fi

  subst_dir="$2"
  echo "flux-command: substituting variables in '${env_file}' in directory ${subst_dir}"

  # Create a list of variables to substitute
  vars="$(grep -Ev "^$|#" "${env_file}" | cut -d= -f1 | awk '{ print "\$\{" $1 "\}" }')"
  echo "flux-command: substituting variables '${vars}'"

  # Export the environment variables
  set -a
  source "${env_file}"
  set +a

  for file in $(find "${subst_dir}" -type f); do
    old_file="${file}.bak"
    cp "${file}" "${old_file}"

    envsubst "${vars}" < "${old_file}" > "${file}"
    rm -f "${old_file}"
  done
}

substitute_vars env_vars .

echo "flux-command: running 'kustomize build' from '${PWD}'"
kustomize build .