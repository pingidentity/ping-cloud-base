Note: The release engineer must have permissions to create tags on these repositories:

- https://gitlab.corp.pingidentity.com/ping-cloud-private-tenant/ping-cloud-base (internal-facing for Ping engineering)
- https://github.com/pingidentity/ping-cloud-base (external-facing for public consumption, e.g. partners)

1. Update the Chagelog.md file with the changes for the new release in GitLab. Obtain the list from Jira to draft the
   changes and go through the MR process as described in git-workflow.txt to have it reviewed by a team member. The MR
   must be targeted to the release branch, e.g. v1.4-release-branch for a v1.4.x release.

2. Run the tag-release.sh script in this directory to create the release tag (e.g. v1.4.2). Refer to its help for usage.
   After the release is tagged, it will take a minute or two for the tag to be propagated from GitLab to GitHub, which
   is our external-facing repository for ping-cloud-base.

3. Once the tag is propagated to GitHub, release the new version on GitHub:
   - Browse to GitHub at https://github.com/pingidentity/ping-cloud-base/releases:
   - Click on the "Draft a new release" button
   - Enter the new tag into the "Choose an existing tag, or create a new tag on publish" field (e.g. v1.4.2)
   - Add the same tag name into "Release title" field as well (e.g. v1.4.2)
   - Copy a few of the most important changes from the release as bullet points and create a link to the full
     Changlog.md for the branch below it, e.g. https://github.com/pingidentity/ping-cloud-base/blob/v1.4.2/Changelog.md