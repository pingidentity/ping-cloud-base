#!/bin/sh

${VERBOSE} && set -x
source ./util.sh

CURRENT_DIRECTORY=$(pwd)

# Allow overriding the Artifact Source URL with an arg
test ! -z "${1}" && ARTIFACT_SOURCE_URL="${1}"
echo "Downloading Artifact ${ARTIFACT_SOURCE_URL}"

# Allow overriding whether the artifact is public/private
test ! -z "${2}" && ARTIFACT_VISIBILITY="${2}"
echo "Artifact visibility is ${ARTIFACT_VISIBILITY}"

# Allow overriding the Artifact Repo Bucket with an arg
test ! -z "${3}" && ARTIFACT_REPO_BUCKET="${3}"
echo "Uploading to location ${ARTIFACT_REPO_BUCKET}"

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

# Extract bucket name
BUCKET_URL_NO_PROTOCOL=${ARTIFACT_REPO_BUCKET#s3://}
BUCKET_NAME=$(echo ${BUCKET_URL_NO_PROTOCOL} | cut -d/ -f1)

# Check to see if the bucket exists
aws s3api head-bucket --bucket ${BUCKET_NAME}
if ! test $(echo $?) == "0"; then
  # Create the bucket
  aws s3api create-bucket --bucket ${BUCKET_NAME}
  check_for_error "Could not create bucket ${BUCKET_NAME}"
fi

# Add /pingfederate to base repo URL
if [ -z "${ARTIFACT_REPO_BUCKET##*/pingfederate*}" ] ;then
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}"
else
    TARGET_BASE_URL="${ARTIFACT_REPO_BUCKET}/pingfederate"
fi

# Extract artifact name and version and initialize the other variables based on the values
ARTIFACT_FILE_NAME="${ARTIFACT_SOURCE_URL##*/}"
echo ${ARTIFACT_FILE_NAME}
ARTIFACT_NAME="${ARTIFACT_FILE_NAME%-*}"
echo ${ARTIFACT_NAME}
ARTIFACT_NAME_WITH_VERSION="${ARTIFACT_FILE_NAME%.*}"
echo ${ARTIFACT_NAME_WITH_VERSION}
ARTIFACT_VERSION="${ARTIFACT_NAME_WITH_VERSION##*-}"
echo ${ARTIFACT_VERSION}
ARTIFACT_EXTENSION="${ARTIFACT_FILE_NAME##*.}"
echo ${ARTIFACT_EXTENSION}
ARTIFACT_RUNTIME_ZIP=${ARTIFACT_NAME_WITH_VERSION}-runtime.zip
echo ${ARTIFACT_RUNTIME_ZIP}

DOWNLOAD_DIR=$(mktemp -d)

# Cleanup artifact folder if it exists
if [ -f "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}" ]
then
    rm -rf "${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}"
fi

# Download artifact zip to tmp
curl -f ${ARTIFACT_SOURCE_URL} --output ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} && echo "Artifact successfully downloaded." || exit 1

if [ ! -f "${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME}" ]
then
    echo Artifact could not be downloaded from ${ARTIFACT_SOURCE_URL}
    exit 1
fi

# Create a working folder to unzip the artifact
mkdir ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}

# Unzip the artifact zip to the working directory
if ! unzip -o ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} -d ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}
then
    echo Artifact ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME} could not be unzipped.
    exit 1
fi

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

# Create the directory structure for the artifact
mkdir ${ARTIFACT_LOCATION}/work
mkdir ${ARTIFACT_LOCATION}/work/deploy
mkdir ${ARTIFACT_LOCATION}/work/conf
mkdir ${ARTIFACT_LOCATION}/work/conf/language-packs
mkdir ${ARTIFACT_LOCATION}/work/conf/template

# Copy the basic jars and wars to deploy
cp ${ARTIFACT_LOCATION}/dist/*.jar ${ARTIFACT_LOCATION}/work/deploy
cp ${ARTIFACT_LOCATION}/dist/*.war ${ARTIFACT_LOCATION}/work/deploy

# Handle the kits where the jars or wars are within deploy
if [ -d "${ARTIFACT_LOCATION}/deploy" ]
then
    cp -r ${ARTIFACT_LOCATION}/deploy/*.jar ${ARTIFACT_LOCATION}/work/deploy
    cp -r ${ARTIFACT_LOCATION}/deploy/*.war ${ARTIFACT_LOCATION}/work/deploy
fi

# Handle the kits where the jars or wars are within dist/deploy
if [ -d "${ARTIFACT_LOCATION}/dist/deploy" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/deploy/*.jar ${ARTIFACT_LOCATION}/work/deploy
    cp -r ${ARTIFACT_LOCATION}/dist/deploy/*.war ${ARTIFACT_LOCATION}/work/deploy
fi

# Handle the war for the VIP IK which exists as a folder
if [ -d "${ARTIFACT_LOCATION}/dist/vip-adapter-security-code-challenge.war" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/*.war ${ARTIFACT_LOCATION}/work/deploy
fi

# Handle the due-web folder for Duo IK which is essentially a war
if [ -d "${ARTIFACT_LOCATION}/dist/duo-web" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/duo-web ${ARTIFACT_LOCATION}/work/deploy
fi

# Handle the sub-folder structure for PingOne for Customers IK
if [ -d "${ARTIFACT_LOCATION}/dist/ds-pcv" ]
then
    cp ${ARTIFACT_LOCATION}/dist/ds-pcv/*.jar ${ARTIFACT_LOCATION}/work/deploy
fi

# Handle the sub-folder structure for PingOne for Customers IK
if [ -d "${ARTIFACT_LOCATION}/dist/provisioner" ]
then
    cp ${ARTIFACT_LOCATION}/dist/provisioner/*.jar ${ARTIFACT_LOCATION}/work/deploy
fi

# Copy the template files if they exist at the root
cp ${ARTIFACT_LOCATION}/dist/*.html ${ARTIFACT_LOCATION}/work/conf/template

# Upload conf folder for PingOne for Customers Integration Kit as it exists inside a specific sub folder
if [ -d "${ARTIFACT_LOCATION}/dist/ds-pcv/conf" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/ds-pcv/conf/* ${ARTIFACT_LOCATION}/work/conf
fi

# Copy the template files if they exist within a separate folder
if [ -d "${ARTIFACT_LOCATION}/dist/template" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/template/* ${ARTIFACT_LOCATION}/work/conf/template
fi

# Copy the template files if they exist within the /conf folder
if [ -d "${ARTIFACT_LOCATION}/conf/template" ]
then
    cp -r ${ARTIFACT_LOCATION}/conf/template/* ${ARTIFACT_LOCATION}/work/conf/template
fi

# Copy language-packs if they exist within a separate folder
if [ -d "${ARTIFACT_LOCATION}/dist/language-packs" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/language-packs/* ${ARTIFACT_LOCATION}/work/conf/language-packs
fi

# Copy language-packs if they exist within the /conf folder
if [ -d "${ARTIFACT_LOCATION}/conf/language-packs" ]
then
    cp -r ${ARTIFACT_LOCATION}/conf/language-packs/* ${ARTIFACT_LOCATION}/work/conf/language-packs
fi

# Copy language-packs if they exist within dist/conf
if [ -d "${ARTIFACT_LOCATION}/dist/conf/language-packs" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/conf/language-packs/* ${ARTIFACT_LOCATION}/work/conf/language-packs
fi

# Copy templates if they exist within the /dist/conf
if [ -d "${ARTIFACT_LOCATION}/dist/conf/template" ]
then
    cp -r ${ARTIFACT_LOCATION}/dist/conf/template/* ${ARTIFACT_LOCATION}/work/conf/template
fi

# Create the runtime zip
cd ${ARTIFACT_LOCATION}/work
zip -r  ${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP} *
cd ${CURRENT_DIRECTORY}

# Upload runtime zip to S3 bucket
echo ${ARTIFACT_LOCATION}/${ARTIFACT_FILE_NAME}
aws s3 cp "${ARTIFACT_LOCATION}/${ARTIFACT_RUNTIME_ZIP}" "${TARGET_BASE_URL}/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/"
check_for_error "Could not upload artifact(s) to ${TARGET_BASE_URL}"

if test ${ARTIFACT_VISIBILITY} == "public"; then
  # Give public read privilige to the uploaded artifact
  aws s3api put-object-acl --bucket ${BUCKET_NAME} --key "pingfederate/${ARTIFACT_NAME}/${ARTIFACT_VERSION}/${ARTIFACT_RUNTIME_ZIP}" --acl public-read
fi

# Cleanup
rm ${DOWNLOAD_DIR}/${ARTIFACT_FILE_NAME}
rm -rf ${DOWNLOAD_DIR}/${ARTIFACT_NAME_WITH_VERSION}

