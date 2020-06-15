#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

test -f "${STAGING_DIR}/env_vars" && . "${STAGING_DIR}/env_vars"

${VERBOSE} && set -x

if test -f "${STAGING_DIR}/artifacts/artifact-list.json"; then
  # Check to see if the artifact file is empty
  ARTIFACT_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/artifact-list.json")
  if test ! -z "${ARTIFACT_LIST_JSON}"; then
    # Check to see if the source S3 bucket(s) are specified
    if test ! -z "${ARTIFACT_REPO_URL}" -o ! -z "${PING_ARTIFACT_REPO_URL}"; then

      echo "Private Repo : ${ARTIFACT_REPO_URL}"
      echo "Public Repo  : ${PING_ARTIFACT_REPO_URL}"

      # Check to see if the artifact list is a valid json string
      echo ${ARTIFACT_LIST_JSON} | jq
      if test $(echo $?) == "0"; then

        DOWNLOAD_DIR="${STAGING_DIR}/pd.profile/server-sdk-extensions"

        # Create extensions folder
        mkdir -p "${DOWNLOAD_DIR}"

        DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

        PUBLIC_BASE_URL="${PING_ARTIFACT_REPO_URL}"
        if test ! -z "${PING_ARTIFACT_REPO_URL}"; then
          if ! test -z "${PING_ARTIFACT_REPO_URL##*/pingdirectory*}"; then
            PUBLIC_BASE_URL="${PING_ARTIFACT_REPO_URL}/${DIRECTORY_NAME}"
          fi
        fi

        PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}"
        if test ! -z "${ARTIFACT_REPO_URL}"; then
          if ! test -z "${ARTIFACT_REPO_URL##*/pingdirectory*}"; then
            PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}/${DIRECTORY_NAME}"
          fi
        fi

        for artifact in $(echo "${ARTIFACT_LIST_JSON}" | jq -c '.[]'); do
          _artifact() {
            echo ${artifact} | jq -r ${1}
          }

          ARTIFACT_NAME=$(_artifact '.name')
          ARTIFACT_VERSION=$(_artifact '.version')
          ARTIFACT_SOURCE=$(_artifact '.source')
          ARTIFACT_FILENAME=$(_artifact '.filename')

          # Use default source of public if source is not specified
          if ( ( test "${ARTIFACT_SOURCE}" == "null" ) || ( test -z ${ARTIFACT_SOURCE} ) ); then
            ARTIFACT_SOURCE="public"
          fi

          if ( ( test ! "${ARTIFACT_FILENAME}" == "null" ) && ( test ! -z ${ARTIFACT_FILENAME} ) ); then
            ARTIFACT_RUNTIME_ZIP="${ARTIFACT_FILENAME}"
          else
            ARTIFACT_RUNTIME_ZIP="pingidentity.com.${ARTIFACT_NAME}-${ARTIFACT_VERSION}.zip"
          fi

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" == "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" == "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Check to see if the Artifact Source URL is available
              if ( ( test "${ARTIFACT_SOURCE}" == "private" ) && ( test -z ${ARTIFACT_REPO_URL} ) ) || ( ( test "${ARTIFACT_SOURCE}" == "public" ) && ( test -z ${PING_ARTIFACT_REPO_URL} ) ); then
                echo "${ARTIFACT_NAME} cannot be deployed as the ${ARTIFACT_SOURCE} source repo is not defined. "
                exit 1
              else

                # Get artifact source location
                if test "${ARTIFACT_SOURCE}" == "private"; then
                  ARTIFACT_LOCATION=${PRIVATE_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}
                elif test "${ARTIFACT_SOURCE}" == "public"; then
                  ARTIFACT_LOCATION=${PUBLIC_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}
                else
                  echo "${ARTIFACT_NAME} cannot be deployed as the artifact source '${ARTIFACT_SOURCE}' is invalid. "
                  exit 1
                fi

                echo "Download Artifact from ${ARTIFACT_LOCATION}"

                # Use skbn command if ARTIFACT_LOCATION is cloud storage otherwise use curl
                if test ${ARTIFACT_LOCATION#s3} != "${ARTIFACT_LOCATION}"; then

                  # Set required environment variables for skbn
                  initializeSkbnConfiguration "${ARTIFACT_LOCATION}"
                  
                  echo "Copying: '${ARTIFACT_RUNTIME_ZIP}' to '${SKBN_K8S_PREFIX}'"

                  if ! skbnCopy "${SKBN_CLOUD_PREFIX}/${ARTIFACT_RUNTIME_ZIP}" "${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}"; then
                    exit 1
                  fi

                else
                  # For downloading over https we need to specify the exact file name,
                  # This will only work for standard extensions with a prefix of pingidentity.com
                  curl -f "${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP}" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} && echo "Artifact successfully downloaded." || exit 1
                fi

                if test $(echo $?) != "0"; then
                  echo "Artifact download failed from ${ARTIFACT_LOCATION}"
                  exit 1
                fi

              fi
            else
              echo "Artifact Version for ${ARTIFACT_NAME} could not be retrieved from ${STAGING_DIR}/artifacts/artifact-list.json"
              exit 1
            fi
          else
            echo "Missing Artifact Name within ${STAGING_DIR}/artifacts/artifact-list.json"
            exit 1
          fi

        done

        # Print listed files from extensions
        ls ${DOWNLOAD_DIR}

      else
        echo "Artifacts will not be deployed as could not parse ${STAGING_DIR}/artifacts/artifact-list.json."
        exit 1
      fi
    else
      echo "Artifacts will not be deployed as the environment variable ARTIFACT_REPO_URL and PING_ARTIFACT_REPO_URL are empty."
      exit 0
    fi
  else
    echo "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json is empty."
    exit 0
  fi
else
  echo "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json doesn't exist."
  exit 0
fi

