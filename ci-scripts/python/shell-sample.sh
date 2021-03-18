#! /bin/bash
echo "-----------------------------------------------------------------------------"
echo " SHELL SCRIPT: Demo AWS CLI command execution"
echo "-----------------------------------------------------------------------------"
aws --profile csg s3 ls
echo "-----------------------------------------------------------------------------"
echo " SHELL SCRIPT: Demo 'kubectl' command execution"
echo "-----------------------------------------------------------------------------"
kubectl get pods --all-namespaces
echo ""
echo ""
echo ""
