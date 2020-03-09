# View the list of standard integration kits available for customers

The public list of PingFederate Integration Kits is available using the AWS Management console, the AWS CLI, or the PingFederate server add ons site.

## Using the AWS CLI

* Enter:

  `aws s3 ls s3://ping-artifacts/pingfederate/  --profile <aws-config-profile>`

  Where \<aws-config-profile> is a profile in your `~/.aws/config` file.

## Using the AWS Management console

1. Log in to your AWS account for the CDE. 
2. From the landing page, go to All Services --> Storage --> S3 --> ping-artifacts --> pingfederate.
   You can then click the Integration Kit you need, the version available, and select to download the ZIP file. 
