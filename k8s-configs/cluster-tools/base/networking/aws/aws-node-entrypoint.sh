#!/bin/bash

# To determine how many pods you can deploy to a node, use the following formula:
# (Number of network interfaces for the instance type × (the number of IP addresses per network interface - 1)) + 2
# Ref: https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html

# Retrieve the instance type from the AWS metadata service
# INSTANCE_TYPE="$(curl http://169.254.169.254/latest/meta-data/instance-type)"

# Ref: https://aws.github.io/aws-eks-best-practices/reliability/docs/networkmanagement/
# Ref: https://github.com/aws/amazon-vpc-cni-k8s/blob/master/docs/eni-and-ip-target.md

# WARM_IP_TARGET:
#     Number of free IP addresses the CNI should keep available. Use this if your subnet is small and you want to
#     reduce IP address usage.
#
# MINIMUM_IP_TARGET:
#     Number of minimum IP addresses the CNI should allocate at node startup.

# Set up MINIMUM_IP_TARGET

# For PD:
# WARM_IP_TARGET: 3
# WARM_ENI_TARGET: 0
# MINIMUM_IP_TARGET: 10 for PD
#   - 3 PD pods
#   - 1 AWS CNI
#   - 1 kube proxy
#   - 1 core DNS (maybe)
#   - 1 NR pod
#   - 3 fudge (periodically used by backups)

exec /app/entrypoint.sh