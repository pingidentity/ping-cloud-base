#!/usr/bin/env sh

${VERBOSE} && set -x

. "${HOOKS_DIR}/pingcommon.lib.sh"
. "${HOOKS_DIR}/utils.lib.sh"

#---------------------------------------------------------------------------------------------
# Main Script 
#---------------------------------------------------------------------------------------------

#
# Run script from known location 
#
currentDir="$(pwd)"
cd /opt/out/instance/bin

#
# Setup S3 bucket path components 
#
directory="$(echo ${PING_PRODUCT} | tr '[:upper:]' '[:lower:]')"
target="${BACKUP_URL}/${directory}"
bucket="${BACKUP_URL#s3://}"
masterKey="${BACKUP_URL}/${directory}/pf.jwk"

#
# Install AWS tools
#
installTools 

#
# If the Pingfederate folder does not exist in the s3 bucket, create it
# 
if [ "$(aws s3 ls ${BACKUP_URL} > /dev/null 2>&1;echo $?)" = "1" ]; then
   aws s3api put-object --bucket "${bucket}" --key "${directory}/"
fi

#
# We may already have a master key on disk if one was supplied through a secret, the 'in' volume or
# extracted from a backup in the drop in deployer directory; in these cases we will use that key 
# during obfuscation. If one does not exist we check to see if one was previously uploaded to s3,
# if so we will use that otherwise we'll create one via obsfuscate.sh. In all cases the key used
# is uploaded to S3 to ensure a common key is used that matches the data archive. 
#
# TODO: Review approach post release as it is currently AWS specific. 
#
if ! [ -f ../server/default/data/pf.jwk ]; then
   echo "No local master key found check s3 for a pre-existing key"
   result="$(aws s3 ls ${masterKey} > /dev/null 2>&1;echo $?)"
   if [ "${result}" = "0" ]; then
      echo "A master key does exist on S3 attempt to retrieve it"
      if [ "$(aws s3 cp "${masterKey}" ../server/default/data/pf.jwk > /dev/null 2>&1;echo $?)" != "0" ]; then
         echo "Retrieval was unsuccessful - crash the container to prevent overwiting the master key"
         exit 1
      else
         echo "Pre-existing master key found - using it"
         obfuscatePassword
      fi
   elif [ "${result}" != "1" ]; then
      echo "Unexpected error accessing S3 - crash the container to prevent overwiting the master key if it exists"
      exit 1
   else
      echo "No pre-existing master key found - obfuscate will create one which we will upload"
      obfuscatePassword
   fi 
else
   echo "A pre-existing master key was found on disk - using it"
   obfuscatePassword
fi
aws s3 cp ../server/default/data/pf.jwk ${target}/pf.jwk
cd "${currentDir}"
