#!/usr/bin/env sh

curl -k https://localhost:9201

for f in *.json; do
  echo "Processing Index State Management Policy file (full path) '${f}'"
  fn=$(basename "${f}")
  n="${fn%.*}"

  echo "Processing file name '${n}'"

curl -s -X PUT "https://localhost:9201/_plugins/_ism/policies/${n}?pretty" -u 'admin:admin' --insecure -H 'Content-Type: application/json' -d"@${f}"
#   ism_policies_response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "https://localhost:9201/_plugins/_ism/policies/${n}?pretty" -u 'admin:admin' --insecure -H 'Content-Type: application/json' -d"@${f}")

#   if [ "${ism_policies_response}" -eq 201 ]; then
#     echo "SUCCESS: ${fn}: processed successfully."
#   else
#     echo "ERROR: ${fn}: processing failed. ResponseCode: ${ism_policies_response}"
#   fi
done