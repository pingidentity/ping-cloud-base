import sys
from botocore.config import Config
import utils
import re as regex
from pkg_resources import parse_version

# Constants
SEMANTIC_VERSION_REGEX = "([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)(_RC[0-9]+)?"


# This class is very similar to the script located in
# ping-cloud-docker/ci-scripts/python/src/get_latest_release_candidate_image.py
# with some changes/additions to account for non-RC tags
class LatestImageManager:
    """Get the latest ECR image"""

    def __init__(self, orig_gitlab_name, repository_name):
        """
            Create initial configuration by connecting to public ECR.

            Arguments
            ----------
            orig_gitlab_name: string
                Gitlab tag name created in repository
            repository_name: string
                Location of image
        """

        self.orig_gitlab_name = orig_gitlab_name
        self.repository_name = repository_name

        # Extract infrastructure version | beluga major version |
        # ping-cloud-base patch | ping-cloud-docker patch from Gitlab tag
        self.infrastructure_version_num, \
        self.beluga_major_version_num, \
        self.pcb_patch_num = self.normalize_gitlab_tag()

        # ECR public only works against us-east-1
        boto_session = utils.get_boto_session()
        config = Config(region_name="us-east-1")
        self.client = boto_session.client("ecr-public", config=config)

    def regex_for_image_within_specific_release(self):
        if "RC" in self.orig_gitlab_name:
            # We only care about the infrastructure version & beluga major version
            return f"({self.infrastructure_version_num})\.({self.beluga_major_version_num})\.([0-9]+)\.([0-9]+)(_RC([0-9]+))?$"
        else:
            # We care about the infrastructure version, beluga major version, & the beluga patch version
            return f"({self.infrastructure_version_num})\.({self.beluga_major_version_num})\.({self.pcb_patch_num})\.([0-9]+)(_RC([0-9]+))?$"

    def normalize_gitlab_tag(self):
        """
          Extract infrastructure version | beluga major version from gitlab tag name.
        """
        gitlab_tag_name = regex.search(SEMANTIC_VERSION_REGEX, self.orig_gitlab_name)

        if gitlab_tag_name is None:
            raise Exception(f"Unexpected Results: Invalid Gitlab tag name - {self.orig_gitlab_name}")

        # Only retrieve pattern #.#.#.#, but only extract the infrastructure, major version, & pcb patch num.
        gitlab_infrastructure_version_num = int(gitlab_tag_name.group(1))
        gitlab_major_version_num = int(gitlab_tag_name.group(2))
        gitlab_pcb_patch_num = int(gitlab_tag_name.group(3))

        # Return integers: infrastructure version | beluga major version | pcb patch num
        return [gitlab_infrastructure_version_num, gitlab_major_version_num, gitlab_pcb_patch_num]

    def get_all_images_in_detail(self):
        """
          Get all images within ECR.

          API Resource:
            https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/ecr-public.html#ECRPublic.Client.describe_image_tags
        """
        all_images = []

        # Make initial API call to get first 1000 images
        response = self.client.describe_image_tags(
            repositoryName=self.repository_name,
            maxResults=1000
        )
        all_images += response.get('imageTagDetails')

        # If there are more than 1000 images, paginate and retrieve the others
        while "nextToken" in response:
            response = self.client.describe_image_tags(
                repositoryName=self.repository_name,
                maxResults=1000,
                nextToken=response["nextToken"]
            )
            all_images += response.get('imageTagDetails')

        return all_images

    def get_latest_image(self):
        """
          Filter out all images that are in the same release (infrastructure_version and beluga_major_version).
          and pcb_patch_num if RC tag
          Return the most recent image for the given product.
        """
        all_images_within_release = []
        for image in self.get_all_images_in_detail():
            orig_image_tag_name = image.get('imageTag')

            if orig_image_tag_name is not None:
                image_tag_name = regex.search(self.regex_for_image_within_specific_release(), orig_image_tag_name)

                if image_tag_name is not None:
                    all_images_within_release.append(orig_image_tag_name)

        if len(all_images_within_release) == 0:
            raise Exception(
                f"No image was found within {self.infrastructure_version_num}.{self.beluga_major_version_num}.{self.pcb_patch_num} release")

        # Sort candidates by highest to lowest. The highest is considered as the most recent.
        sorted_images = sorted(all_images_within_release, key=parse_version, reverse=True)

        # Return the first item from the list. This is the latest candidate within the release.
        return sorted_images[0]


if __name__ == '__main__':
    repo_name = sys.argv[1]
    tag = sys.argv[2]

    lim = LatestImageManager(tag, repo_name)
    print(lim.get_latest_image())
