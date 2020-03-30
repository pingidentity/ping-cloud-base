# Development Notes

Use the following steps for testing server profiles during development. 

1. Create a local branch and make your server profile changes in that branch.

2. Commit your changes with a commit message prefix of "[skip pipeline]" and push the branch up to the GitLab server.
   It will automatically be mirrored to AWS Code Commit in the CSG Beluga AWS account. This is required so that your 
   containers running on EKS are able to git-clone the server profiles repo. 
   
   Note: We currently have a unique situation with server profiles. Git best practices dictate that you only push your 
   changes after you've tested your feature branch, i.e. try not to commit, then push repeatedly. Every push will 
   trigger a pipeline on the server, which will flood the shared CI/CD cluster. So make sure to use "[skip pipeline]" 
   until you have fully tested your server profile changes. 

3. The SERVER_PROFILE_URL for all supported products already points to the mirrored repository on AWS Code Commit.
   But the SERVER_PROFILE_BRANCH and SERVER_PROFILE_PATH variables must be configured correctly for development.

   3.a. SERVER_PROFILE_BRANCH should be set to the branch that was pushed up in step 1 using the CONFIG_REPO_BRANCH
        environment variable to the dev-env.sh script.

   3.b. Each product uses its own directory for SERVER_PROFILE_PATH by default. It is typically in the format
        profiles/${CONFIG_PARENT_DIR}/${PRODUCT}. CONFIG_PARENT_DIR is the parent directory within which the profiles
        for the different products exist, e.g. dev, aws, etc. PRODUCT is the well-known DevOps product name for the
        Ping apps, e.g. pingdirectory, pingfederate, etc. For example, pingdirectory uses profiles/aws/pingdirectory by
        default. So the only variable in this format is CONFIG_PARENT_DIR, and it can be supplied as a variable to the
        dev-env.sh script, if desired.

4. Run the dev-env.sh script in dry-mode (with -n option), and verify that the SERVER_PROFILE_* variables are set to 
   the correct values in /tmp/deploy.yaml.
   
        source <your-env-variables-file>; CONFIG_REPO_BRANCH=$(git rev-parse --abbrev-ref HEAD) ./dev-env.sh -n

5. Run the dev-env.sh script without the -n option, and verify that the Ping apps come up and function as expected.

        source <your-env-variables-file>; CONFIG_REPO_BRANCH=$(git rev-parse --abbrev-ref HEAD) ./dev-env.sh
        
6. Use steps 1 through 5 to verify that your server profile changes work as expected. Then, push the tested changes
   without the "[skip pipeline]" commit message prefix.

7. When the pipeline for the branch passes, open an MR to merge the change into the target branch. Refer to the 
   git-workflow.txt document under ping-cloud-base for instructions on MRs.