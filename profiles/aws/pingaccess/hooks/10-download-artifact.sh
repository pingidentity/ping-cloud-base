#!/usr/bin/env sh

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

${VERBOSE} && set -x

if test -f "${STAGING_DIR}/artifacts/artifact-list.json"; then
  # Check to see if the artifact file is empty
  ARTIFACT_LIST_JSON=$(cat "${STAGING_DIR}/artifacts/artifact-list.json")
  if test ! -z "${ARTIFACT_LIST_JSON}"; then
    # Check to see if the source is specified
    if test ! -z "${ARTIFACT_REPO_URL}"; then

      beluga_log "Private Repo : ${ARTIFACT_REPO_URL}"

      # Check to see if the artifact list is a valid json string
      beluga_log "${ARTIFACT_LIST_JSON}"
      if test $(echo ${ARTIFACT_LIST_JSON} | jq >/dev/null 2>&1; echo $?) == "0"; then

        DOWNLOAD_DIR=$(mktemp -d)
        UNZIP_DOWNLOAD_DIR=$(mktemp -d)
        DIRECTORY_NAME=$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')

        PRIVATE_BASE_URL="${ARTIFACT_REPO_URL}"
        if test ! -z "${ARTIFACT_REPO_URL}"; then
          if ! test -z "${ARTIFACT_REPO_URL##*/pingaccess*}"; then
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
          ARTIFACT_OPERATION=$(_artifact '.operation')
          ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME}-${ARTIFACT_VERSION}-runtime.zip

          # Use default source of private if source is not specified
          if ( ( test "${ARTIFACT_SOURCE}" == "null" ) || ( test -z ${ARTIFACT_SOURCE} ) ); then
            ARTIFACT_SOURCE="private"
          fi

          # Use default operation of add if operation is not specified
          if ( ( test "${ARTIFACT_OPERATION}" == "null" ) || ( test -z ${ARTIFACT_OPERATION} ) ); then
            ARTIFACT_OPERATION="add"
          fi

          # Check to see if artifact name and version are available
          if ( ( test ! "${ARTIFACT_NAME}" == "null" ) && ( test ! -z ${ARTIFACT_NAME} ) ); then
            if ( ( test ! "${ARTIFACT_VERSION}" == "null" ) && ( test ! -z ${ARTIFACT_VERSION} ) ); then

              # Check to see if the Artifact Source URL is available
              if ( ( test "${ARTIFACT_SOURCE}" == "private" ) && ( test -z ${ARTIFACT_REPO_URL} ) ); then
                beluga_log "${ARTIFACT_NAME} cannot be deployed as the ${ARTIFACT_SOURCE} source repo is not defined. "
                exit 1
              else
                # Make sure there aren't any duplicate entries for the artifact.
                # This is needed to avoid issues with multiple plugin versions
                ARTIFACT_NAME_COUNT=$(echo "${ARTIFACT_LIST_JSON}" | grep -iEo "${ARTIFACT_NAME}" | wc -l | xargs)

                if test "${ARTIFACT_NAME_COUNT}" == "1"; then

                  # Get artifact source location
                  if test "${ARTIFACT_SOURCE}" == "private"; then
                    ARTIFACT_LOCATION=${PRIVATE_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}
                  else
                    beluga_log "${ARTIFACT_NAME} cannot be deployed as the artifact source '${ARTIFACT_SOURCE}' is invalid. "
                    exit 1
                  fi

                  beluga_log "Download Artifact from ${ARTIFACT_LOCATION}"

                  # Use skbn command if ARTIFACT_LOCATION is in s3 format otherwise use curl
                  if ! test ${ARTIFACT_LOCATION#s3} == "${ARTIFACT_LOCATION}"; then

                    # Set required environment variables for skbn
                    initializeSkbnConfiguration "${ARTIFACT_LOCATION}"
                  
                    beluga_log "Copying: '${ARTIFACT_RUNTIME_ZIP}' to '${SKBN_K8S_PREFIX}'"

                    if ! skbnCopy "${SKBN_CLOUD_PREFIX}" "${SKBN_K8S_PREFIX}${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}"; then
                      beluga_log "Failed to copy ${ARTIFACT_RUNTIME_ZIP}"
                      exit 1
                    fi

                  else
                    curl -sS "${ARTIFACT_LOCATION}" --output ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  fi

                  if test $(echo $?) == "0"; then

                    # Unzip artifact plugin
                    if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} -d ${UNZIP_DOWNLOAD_DIR}; then
                        beluga_log Artifact ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP} could not be unzipped.
                        exit 1
                    fi

                    # Validate /lib directory is included in the zip and the artifact jar
                    ! test -d ${UNZIP_DOWNLOAD_DIR}/lib && beluga_log "Artifact required lib directory could not be found." && exit 1
                    ! test -f ${UNZIP_DOWNLOAD_DIR}/lib/*jar && beluga_log "Artifact required jar file could not be found." && exit 1

                    # Extend the permissions of all detected jars
                    find ${UNZIP_DOWNLOAD_DIR} -name *.jar -exec chmod 777 {} \;

                    # If exist remove any previous versions of artifact plugin
                    test -f ${OUT_DIR}/instance/lib/${ARTIFACT_NAME}-[0-9]*.jar && \
                    rm ${OUT_DIR}/instance/lib/${ARTIFACT_NAME}-[0-9]*.jar

                    # Deploy artifact plugin to server
                    cp -prf ${UNZIP_DOWNLOAD_DIR}/* ${OUT_DIR}/instance

                    beluga_log "Artifact ${ARTIFACT_RUNTIME_ZIP} successfully deployed"

                  else
                    beluga_log "Artifact download failed from ${ARTIFACT_LOCATION}"
                    exit 1
                  fi

                  # Cleanup
                  test -f "${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}" && rm ${DOWNLOAD_DIR}/${ARTIFACT_RUNTIME_ZIP}
                  test -d "${UNZIP_DOWNLOAD_DIR}" && rm -rf "${UNZIP_DOWNLOAD_DIR}"

                else
                  beluga_log "Artifact ${ARTIFACT_NAME} is specified more than once in ${STAGING_DIR}/artifacts/artifact-list.json"
                  exit 1
                fi
              fi
            else
              beluga_log "Artifact Version for ${ARTIFACT_NAME} could not be retrieved from ${STAGING_DIR}/artifacts/artifact-list.json"
              exit 1
            fi
          else
            beluga_log "Missing Artifact Name within ${STAGING_DIR}/artifacts/artifact-list.json"
            exit 1
          fi

        done

        # Print listed files from deploy and conf to a single line so we don't spam logs
        ls ${OUT_DIR}/instance/lib | xargs

      else
        beluga_log "Artifacts will not be deployed as could not parse ${STAGING_DIR}/artifacts/artifact-list.json."
        exit 1
      fi
    else
      beluga_log "Artifacts will not be deployed as the environment variable ARTIFACT_REPO_URL and PING_ARTIFACT_REPO_URL are empty."
      exit 0
    fi
  else
    beluga_log "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json is empty."
    exit 0
  fi
else
  beluga_log "Artifacts will not be deployed as ${STAGING_DIR}/artifacts/artifact-list.json doesn't exist."
  exit 0
fi
