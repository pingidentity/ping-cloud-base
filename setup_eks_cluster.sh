#!/bin/bash

clusterName="${USER}"
bucketName="${clusterName}-csd-archives-bucket"
region="us-west-2"
vpcCidr="172.90.0.0/16" 
instanceType="r5a.xlarge"
profile="softserve"
nodeZones="${region}a,${region}b,${region}c"
version=1.14

hostedZone="${USER}.ping-demo.com"
teamName="PingCloud"
expirationDate="always_in_use"
workload="testenv"

cidrMask=$(echo "$(echo ${vpcCidr} | cut -d "." -f -2 ).*.*/*")

createCluster()
{
   eksctl create cluster \
      --name ${clusterName} \
      --region ${region} \
      --version ${version} \
      --without-nodegroup \
      --vpc-cidr ${vpcCidr} \
      --zones "${nodeZones}" \
      --kubeconfig ~/.kube/config.${clusterName} \
      --profile ${profile} | tee /tmp/eks.out \
      --tags email=${USER}@pingidentity.com,team=${teamName},retain=true,expiration=${expirationDate},workload=${workload}
}

getStacksNames()
{
   stacksNames=()
   separatedNodeZones=$(echo ${nodeZones} | tr "," "\n")

   for nodeZone in $separatedNodeZones
   do
      stacksNames+=("eksctl-${clusterName}-nodegroup-${nodeZone}-worker-nodes")
   done

   stacksNames+=("eksctl-${clusterName}-cluster")
}

setStacksTags()
{
   # adding tags to stacks after creating

   getStacksNames

   for stackName in "${stacksNames[@]}"
   do
   aws cloudformation update-stack \
      --region ${region} \
      --stack-name ${stackName} \
      --use-previous-template \
      --capabilities CAPABILITY_IAM \
      --tags "Key=email,Value=${USER}@pingidentity.com" \
               "Key=team,Value=${teamName}" \
               "Key=retain,Value=true" \
               "Key=expiration,Value=${expirationDate}" \
               "Key=workload,Value=${workload}"
   done
}

createNodeGroup()
{
   for AZ in $(echo ${nodeZones} | tr ',' ' '); do
      eksctl create nodegroup \
         --cluster ${clusterName} \
         --node-zones ${AZ} \
         --name ${AZ}-worker-nodes \
         --node-labels="role=pingdirectory" \
         --managed \
         --node-type ${instanceType} \
         --nodes-min 1 \
         --nodes 1 \
         --nodes-max 2 \
         --node-volume-size 20 \
         --ssh-access \
         --ssh-public-key=/Users/${USER}/.ssh/csgaws.pub \
         --asg-access \
         --profile ${profile} \
         --tags email=${USER}@pingidentity.com,team=${teamName},retain=true,expiration=${expirationDate},workload=${workload} | \
         tee -a /tmp/eks.out
   done
}

createBucket()
{
   aws s3api create-bucket \
      --bucket ${bucketName} \
      --region ${region} \
      --create-bucket-configuration LocationConstraint=${region} \
      --profile ${profile} | tee -a /tmp/eks.out

   aws s3api put-object \
      --bucket ${bucketName} \
      --key pingdirectory \
      --profile ${profile} | tee -a /tmp/eks.out

   # adding of tags set after bucket creating
   aws s3api put-bucket-tagging \
      --bucket ${bucketName} \
      --tagging "TagSet=[{Key=email,Value=${USER}@pingidentity.com},{Key=team,Value=${teamName}},{Key=retain,Value=true},{Key=expiration,Value=${expirationDate}},{Key=workload,Value=${workload}}]"
}

getHostedZoneId()
{
   # setting a variable that uses in createHostedZone and cleanup functions
   hostedZoneId=$(aws route53 list-hosted-zones-by-name | \
                  jq --arg hostedZone "$hostedZone." '."HostedZones" | .[] | select (.Name==$hostedZone) | .Id' | \
                  awk -F '/' '{ print $3 }' | \
                  sed -e 's/"$//')
}

createHostedZone()
{
   aws route53 create-hosted-zone \
      --name ${hostedZone} \
      --caller-reference $(date +%s) \
      --hosted-zone-config \
         Comment="${USER} development environment",PrivateZone=false

   getHostedZoneId

   # adding of tags set after hosted zone creating
   if [ ! -z "${hostedZoneId}" ]; then
      aws route53 change-tags-for-resource \
         --resource-type hostedzone \
         --resource-id ${hostedZoneId} \
         --add-tags "Key=email,Value=${USER}@pingidentity.com" \
                    "Key=team,Value=${teamName}" \
                    "Key=retain,Value=true" \
                    "Key=expiration,Value=${expirationDate}" \
                    "Key=workload,Value=${workload}"

      aws route53 list-tags-for-resources \
         --resource-type hostedzone \
         --resource-ids ${hostedZoneId}
   fi
}

getVPCid()
{
   # variable that uses in setELBtags and setVPCtags functions
   vpcId=$(aws ec2 describe-vpcs \
            --region ${region} \
            --filters Name=cidr,Values=${cidrMask} | \
            jq '.[] | .[].VpcId' | \
            tr -d '"')
}

setELBtags()
{
   # setting ELB tags set after resource creation

   getVPCid

   ELBarns=$(aws elbv2 describe-load-balancers \
      --region ${region} | \
      jq --arg vpcId "$vpcId" '."LoadBalancers" | .[] | select (.VpcId==$vpcId) | .LoadBalancerArn' | \
      tr -d '"')

   for ELB in $ELBarns
   do
      aws elbv2 add-tags \
         --region ${region} \
         --resource-arns ${ELB} \
         --tags "Key=email,Value=${USER}@pingidentity.com" \
                "Key=team,Value=${teamName}" \
                "Key=retain,Value=true" \
                "Key=expiration,Value=${expirationDate}" \
                "Key=workload,Value=${workload}"

      aws elbv2 describe-tags \
         --region ${region} \
         --resource-arns ${ELB}
   done
}

setVPCtags()
{
   # setting VPC tags set after resource creation

   getVPCid

   aws ec2 create-tags \
      --region ${region} \
      --resources ${vpcId} \
      --tags "Key=email,Value=${USER}@pingidentity.com" \
             "Key=team,Value=${teamName}" \
             "Key=retain,Value=true" \
             "Key=expiration,Value=${expirationDate}" \
             "Key=workload,Value=${workload}"
}

getIAMrolesNames()
{
   IAMroles=$(aws iam list-roles | \
               jq '."Roles" | .[] | .RoleName' | \
               grep "${clusterName}" | \
               tr -d '"')
}

getEFSid()
{
   EFSid=$(aws efs describe-file-systems \
            --profile ${USER}
            --region ${region} | \
            jq --arg creationToken "$creationToken" '.[] | .[] | select (.CreationToken==$creationToken) | .FileSystemId' | \
            tr -d '"')
}

createEFSfilesystem()
{
   # Creation of OFS filesystem that required for logstash enrichment service

   export creationToken=EnrichmentEFS-$RANDOM

   aws efs create-file-system \
      --creation-token ${creationToken} \
      --performance-mode generalPurpose \
      --throughput-mode bursting \
      --region ${region} \
      --tags "Key=email,Value=${USER}@pingidentity.com" \
             "Key=team,Value=${teamName}" \
             "Key=retain,Value=true" \
             "Key=expiration,Value=${expirationDate}" \
             "Key=workload,Value=${workload}" \
      --profile ${USER}

   getEFSid

   getVPCid

   subnetIds=$(aws ec2 describe-subnets \
               --region ${region} | \
               jq '.[] | .[] | select(.VpcId==$vpcId) | .SubnetId' | \
               tr -d '"')

   sgId=$(aws ec2 describe-security-groups \
            --region ${region} | \
            jq --arg vpcId "$vpcId" '.[] | .[] | select(.VpcId==$vpcId) | select(.GroupName | startswith("eks-cluster-sg")) | .GroupId' | \
            tr -d '"')

   for subnetId in $subnetIds
   do
      aws efs create-mount-target \
         --file-system-id ${EFSid} \
         --subnet-id ${subnetId} \
         --security-group ${sgId} \
         --region ${region} \
         --profile ${USER}
   done

   export EFS_FILESYSTEM_ID=$EFSid
}

cleanup()
{
   # delete nodegroups 

   for AZ in $(echo ${nodeZones} | tr ',' ' '); do
      eksctl delete nodegroup \
         --cluster ${clusterName} \
         --name ${AZ}-worker-nodes \
         --profile ${profile}
   done

   # delete cluster

   eksctl delete cluster \
      --name ${clusterName} \
      --region ${region} \
      --profile ${profile}

   #delete S3 bucket

   aws s3 rb --force s3://${bucketName} \
      --profile ${profile}

   # delete IAM roles

   getIAMrolesNames

   for role in $IAMroles
   do
      aws iam delete-role \
         --role-name ${role}
   done

   # delete VPCs

   getVPCid

   aws ec2 delete-vpc \
      --region ${region} \
      --vpc-id ${vpcId}

   # delete Cloudformation stacks

   getStacksNames

   for stackName in "${stacksNames[@]}"
   do
      aws cloudformation delete-stack \
         --region ${region} \
         --stack-name ${stackName}
   done

   # delete HostedZones

   getHostedZoneId

   if [ ! -z "${hostedZoneId}" ]; then
      aws route53 delete-hosted-zone \
         --id ${hostedZoneId}
   fi

   # delete EFS filesystem

   getEFSid

   if [ ! -z "${EFSid}" ]; then
      aws efs delete-file-system \
         --file-system-id ${EFSid}
   fi

}

# Runner part

while getopts 'actd' OPTION
do
  case ${OPTION} in
    a)
      # Create all resources and tag it
      createBucket
      createCluster
      createNodeGroup
      createHostedZone
      createEFSfilesystem
      setStacksTags
      setELBtags
      setVPCtags
      ;;
    c)
      # Create all resources without tagging
      createBucket
      createCluster
      createNodeGroup
      createHostedZone
      createEFSfilesystem
      ;;
    t)
      # Tag resources that already exist
      setStacksTags
      setELBtags
      setVPCtags
      ;;
    d)
      # Delete all resources
      cleanup
      ;;
    *)
      echo "Usage: a - create all resources and tag it; c - create all resources without tagging; t - tag resources that already exist; d - delete all resources"
      popd  > /dev/null 2>&1
      exit 1
      ;;
  esac
done

read -p "Any key to import configuration, ctrl-c to exit"
aws eks update-kubeconfig --name ${clusterName} --region ${region}