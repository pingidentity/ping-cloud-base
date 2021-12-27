#!/bin/sh
​
${VERBOSE} && set -x
source ./util.sh
​
CURRENT_DIRECTORY=$(pwd)
​
# Allow overriding the Artifact Source URL with an arg
test ! -z "${1}" && ARTIFACT_SOURCE_URL="${1}"
echo "Downloading Artifact ${ARTIFACT_SOURCE_URL}"
​
# Allow overriding whether the artifact is public/private
test ! -z "${2}" && ARTIFACT_VISIBILITY="${2}"
echo "Artifact visibility is ${ARTIFACT_VISIBILITY}"
​
# Allow overriding the Artifact Repo Bucket with an arg
test ! -z "${3}" && ARTIFACT_REPO_BUCKET="${3}"
echo "Uploading to location ${ARTIFACT_REPO_BUCKET}"
​
# Install AWS CLI if the upload location is S3
if test "${ARTIFACT_REPO_BUCKET#s3}" == "${ARTIFACT_REPO_BUCKET}"; then
    echo "Upload location is not S3"
    exit 0
elif ! which aws > /dev/null; then
    echo "Installing AWS CLI"
    apk --update add python3
    pip3 install --no-cache-dir --upgrade pip
    pip3 install --no-cache-dir --upgrade awscli
fi
​
# Extract bucket name
BUCKET_URL_NO_PROTOCOL=${ARTIFACT_REPO_BUCKET#s3://}
BUCKET_NAME=$(echo ${BUCKET_URL_NO_PROTOCOL} | cut -d/ -f1)
​
# Check to see if the bucket exists
aws s3api head-bucket --bucket ${BUCKET_NAME}
if ! test $(echo $?) == "0"; then
  # Create the bucket
  aws s3api create-bucket --bucket ${BUCKET_NAME}
  check_for_error "Could not create bucket ${BUCKET_NAME}"
fi
​
# Add /pingfederate to base repo URL
if [ -z "${ARTIFACT_REPO_BUCKET##*/pingfederate*}" ] ;then
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}"
else
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}/pingfederate"
fi
​
# Extract artifact name and version and initialize the other variables based on the values
ARTIFACT_FILE_NAME="${ARTIFACT_SOURCE_URL##*/}"
echo " << ARTIFACT_FILE_NAME: ${ARTIFACT_FILE_NAME} >> "
ARTIFACT_NAME="${ARTIFACT_FILE_NAME%-*}"
echo " << ARTIFACT_NAME: ${ARTIFACT_NAME} >> "
ARTIFACT_NAME_WITH_VERSION="${ARTIFACT_FILE_NAME%.*}"
echo " << ARTIFACT_NAME_WITH_VERSION: ${ARTIFACT_NAME_WITH_VERSION} >> "
ARTIFACT_VERSION="${ARTIFACT_NAME_WITH_VERSION##*-}"
echo " << ARTIFACT_VERSION: ${ARTIFACT_VERSION} >> "
ARTIFACT_EXTENSION="${ARTIFACT_FILE_NAME##*.}"
echo " << ARTIFACT_EXTENSION: ${ARTIFACT_EXTENSION} >> "
ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME_WITH_VERSION}-runtime.zip
echo " << ARTIFACT_RUNTIME_ZIP: ${ARTIFACT_RUNTIME_ZIP} >> "
​
DOWNLOAD_DIR=$(mktemp -d)
​
# Cleanup artifact folder if it exists
if [ -f "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}" ]
then
    rm -rf "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}"
fi
​
# Download artifact zip to tmp
curl -f ${ARTIFACT_SOURCE_URL} --output ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} && echo "Artifact successfully downloaded." || exit 1
​
if [ ! -f "${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME}" ]
then
    echo Artifact could not be downloaded from ${ARTIFACT_SOURCE_URL}
    exit 1
fi
​
# Create a working folder to unzip the artifact
mkdir ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}
​
echo " <<< Download dir: ${DOWNLOAD_DIR} >>> "
echo " <<< Unzipping the Artifact >>> "
​
# Unzip the artifact zip to the working directory
if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} -d ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}
then
    echo Artifact ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} could not be unzipped.
    exit 1
fi
​
# Retrieve the exact path of components within the artifact zip
if [ -d "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME}" ]
then
    ARTIFACT_LOCATION="${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME}"
elif [ -d "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME_WITH_VERSION}" ]
then
    ARTIFACT_LOCATION="${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_NAME_WITH_VERSION}"
else
    # Sub folder is not the artifact name so enumerate and get the dynamic value
    cd ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}
    ARTIFACT_SUB_FOLDER=$(find . -mindepth 1 -maxdepth 1 -type d  \( ! -iname "[_.]*" \) | sed 's|^\./||g')
    ARTIFACT_LOCATION="${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}/${ARTIFACT_SUB_FOLDER}"
    cd ${CURRENT_DIRECTORY}
fi
​
# Create the directory structure for the artifact
mkdir ${ARTIFACT_LOCATION}/work
​
# Packaging as per IK standards 
# Copy the Legal.pdf file if exists at the root
echo " <<< Copy the Legal.pdf file if exists at the root >>> "
cp ${ARTIFACT_LOCATION}/Legal.pdf ${ARTIFACT_LOCATION}/work
​
# Copy config folder
echo " <<< Copy config folder >>> "
if [ -d "${ARTIFACT_LOCATION}/config" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/config && cp -r ${ARTIFACT_LOCATION}/config/* ${ARTIFACT_LOCATION}/work/config
fi
​
# Copy language-packs folder
echo " <<< Copy language-packs folder >>> "
if [ -d "${ARTIFACT_LOCATION}/dist/pingfederate/server/default/conf/language-packs" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/conf/language-packs && \
    cp -r ${ARTIFACT_LOCATION}/dist/pingfederate/server/default/conf/language-packs/* ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/conf/language-packs
fi
​
# Copy deploy folder
echo " <<< Copy deploy folder >>> "
if [ -d "${ARTIFACT_LOCATION}/dist/pingfederate/server/default/deploy" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/deploy && \
    cp -r ${ARTIFACT_LOCATION}/dist/pingfederate/server/default/deploy/* ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/deploy
fi
​
# Copy lib folder
echo " <<< Copy lib folder >>> "
if [ -d "${ARTIFACT_LOCATION}/dist/pingfederate/server/default/lib" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/lib && \
    cp -r ${ARTIFACT_LOCATION}/dist/pingfederate/server/default/lib/* ${ARTIFACT_LOCATION}/work/dist/pingfederate/server/default/lib
fi
​
# Copy sample folder
echo " <<< Copy sample folder >>> "
if [ -d "${ARTIFACT_LOCATION}/sample" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/sample && \
    cp -r ${ARTIFACT_LOCATION}/sample/* ${ARTIFACT_LOCATION}/work/sample
fi
​
# Copy metadata folder
echo " <<< Copy metadata folder >>> "
if [ -d "${ARTIFACT_LOCATION}/metadata" ]
then
    mkdir -p ${ARTIFACT_LOCATION}/work/metadata && \
    cp -r ${ARTIFACT_LOCATION}/metadata/* ${ARTIFACT_LOCATION}/work/metadata
fi
​
# Create the runtime zip
echo " <<< Create the runtime zip at: ${ARTIFACT_LOCATION} >>> "
cd ${ARTIFACT_LOCATION}/work
zip -r  ${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP} *
cd ${CURRENT_DIRECTORY}
​
# Upload runtime zip to S3 bucket
echo " <<< Upload runtime zip to S3 bucket >>> "
echo ${ARTIFACT_LOCATION}/${ARTIFACT_FILE_NAME}
aws s3 cp "${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP}" "${TARGET_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/"
check_for_error "Could not upload artifact(s) to ${TARGET_BASE_URL}"
​
if test ${ARTIFACT_VISIBILITY} == "public"; then
  # Give public read privilige to the uploaded artifact
  aws s3api put-object-acl --bucket ${BUCKET_NAME} --key "pingfederate/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}" --acl public-read
fi
​
# Cleanup
echo " <<< Cleanup >>> "
rm ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME}
rm -rf ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}