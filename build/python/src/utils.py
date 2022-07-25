import logging
import os
import sys
import boto3


def set_up_logger(name):
    logger = logging.getLogger("check_image")
    logging.basicConfig(
        format="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
        stream=sys.stdout,
        level=logging.WARNING
    )

    return logger


logger = set_up_logger(__name__)


def get_branch(root_dir) -> str:
    """
    Get the current branch name

    Args:
        root_dir (string): Root directory of the repo

    Returns:
        string: the current branch name, lowercase (same as bash script)
    """
    if check_in_gitlab():
        return os.environ.get("CI_COMMIT_REF_NAME")


def get_boto_session() -> boto3.session.Session:
    """
    Gets a boto3 session depending on whether we are running in a local
    environment or in Gitlab. Validates the session before returning it.

    Returns:
        boto3 session: A valid boto3 session for the environment (gitlab or local)
    """
    session = boto3.session.Session()
    check_boto_session(session)
    return session


def check_boto_session(boto_session) -> None:
    """
    Checks validity of a boto3 session

    Args:
        boto_session (boto3 Session): session to check the validity of

    Returns:
        Exits non-zero if a non valid session, otherwise nothing returned.
    """

    try:
        boto_session.client("sts").get_caller_identity()
    except Exception as e:
        logger.exception(f"AWS boto encountered an exception: {e}")
        sys.exit(1)


def check_in_gitlab() -> bool:
    """
    Returns:
        True if we are in a gitlab environment (based on CI_SERVER
        environment variable being set), False otherwise
    """
    return True if os.environ.get("CI_SERVER", "no") == "yes" else False
