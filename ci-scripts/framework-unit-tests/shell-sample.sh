#! /bin/bash
printf -- "${yellow}${italic}-----------------------------------------------------------------------------\\n"
printf -- " SHELL SCRIPT: Demo AWS CLI command execution -- List S3 buckets\\n"
printf -- "-----------------------------------------------------------------------------${normal}\\n"
aws --profile csg s3 ls
printf -- "${blue}${italic}-----------------------------------------------------------------------------\\n"
printf -- " SHELL SCRIPT: Demo 'kubectl' command execution -- List pods all namespaces\\n"
printf -- "-----------------------------------------------------------------------------${normal} \\033[0m\\n"
kubectl get pods --all-namespaces
printf "\\n"
printf "\\n"
printf "\\n"
