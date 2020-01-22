This directory structure may be used for testing server profiles during development. After making the desired changes
to the server profiles, use the following steps to test them:

1. Push a new git branch in the format profile-test-${USER} into GitLab. This is a protected branch and so will
   automatically be mirrored to the public GitHub repo at https://github.com/pingidentity/ping-cloud-base.git instantly.

2. The SERVER_PROFILE_URL for all supported products is already pointing to the above GitHub repository. But the
   SERVER_PROFILE_BRANCH and SERVER_PROFILE_PATH variables must be configured correctly for development.

   2.a. SERVER_PROFILE_BRANCH should be set to the branch that was pushed up in step 1 using the CONFIG_REPO_BRANCH
        environment variable to the dev-env.sh script.

   2.b. Each product uses its own directory for SERVER_PROFILE_PATH by default. It is typically in the format
        profiles/${CONFIG_PARENT_DIR}/${PRODUCT}. CONFIG_PARENT_DIR is the parent directory within which the profiles
        for the different products exist, e.g. dev, aws, etc. PRODUCT is the well-known DevOps product name for the
        Ping apps, e.g. pingdirectory, pingfederate, etc. For example, pingdirectory uses profiles/aws/pingdirectory by
        default. So the only variable in this format is CONFIG_PARENT_DIR, and it can be supplied as a variable to the
        dev-env.sh script.

3. Run the dev-env.sh script in dry-mode (with -n option) and verify that the SERVER_PROFILE_* variables are set to the
   correct values in /tmp/deploy.yaml.

4. Run the dev-env.sh script and verify that the Ping apps come up and function as expected.

5. When satisfied with the changes, copy the changes into the official profiles parent directory, e.g. aws.

6. Use steps 1 through 5 to verify that the profiles under the new parent directory work as expected.

7. When the pipeline for the branch passes, open an MR to merge the change into the master branch.

8. When done with testing and you no longer desire to keep the protected branch created in step 1 around, then let the
   ping-cloud-base repository maintainer know so they can delete the protected branch from both GitLab and GitHub.