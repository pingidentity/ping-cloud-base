import unittest
import os
import json
import boto3
import k8s_utils
import logging

from datetime import datetime, timedelta
import tenacity

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s: %(name)s %(levelname)s %(message)s",
)

TENACITY_LOGGER = logging.getLogger("Retrying")

test_retry=tenacity.retry(
    stop=tenacity.stop_after_attempt(15),
    wait=tenacity.wait_random_exponential(5, 300),
    after=tenacity.after_log(TENACITY_LOGGER, logging.WARNING),
)

dt_now = datetime.now()
delta = dt_now - timedelta(hours=0, minutes=60)
dt_now_ms = round(dt_now.timestamp() * 1000)
dt_past_ms = round(delta.timestamp() * 1000)


class TestCloudWatchLogs(unittest.TestCase):
    log_lines = int(os.getenv("LOG_LINES_TO_TEST", 10))

    aws_region = os.getenv("AWS_REGION", "us-west-2")
    aws_client = boto3.client("logs", region_name=aws_region)

    # Change the pod_labels, pod_namespace, and container_name to use this test with another application.
    pod_labels = "k8s-app=fluent-bit"
    pod_namespace = "elastic-stack-logging"
    container_name = "fluent-bit"
    k8s_cluster_name = os.getenv("CLUSTER_NAME")
    log_group_name = f"/aws/containerinsights/{k8s_cluster_name}/application"

    @classmethod
    def setUpClass(cls) -> None:
        cls.k8s = k8s_utils.K8sUtils()

    def get_latest_cw_logs(self) -> list:
        events = []
        cw_logs = []
        pod_name = self.k8s.get_first_matching_pod_name(self.pod_namespace, self.pod_labels)
        log_stream_name = f"{pod_name}_{self.pod_namespace}_{self.container_name}"
        # first request
        response = self.aws_client.get_log_events(
            logGroupName=self.log_group_name,
            logStreamName=log_stream_name,
            startTime=dt_past_ms,
            endTime=dt_now_ms,
            startFromHead=True)
        events.extend(response['events'])

        # second and later
        while True:
            prev_token = response['nextForwardToken']
            response = self.aws_client.get_log_events(
                logGroupName=self.log_group_name,
                logStreamName=log_stream_name,
                nextToken=prev_token)
            # same token then break
            if response['nextForwardToken'] == prev_token:
                break
            events.extend(response['events'])

        for event in events:
            cw_logs.append(json.loads(event["message"])["log"].replace("\n", ""))

        return cw_logs

    def test_cloudwatch_log_group_exists(self):
        response = self.aws_client.describe_log_groups(
            logGroupNamePrefix=self.log_group_name
        )

        self.assertNotEqual(response["logGroups"], [], "Required log groups not found")

    def test_cloudwatch_log_stream_exists(self):
        pod_name = self.k8s.get_first_matching_pod_name(self.pod_namespace, self.pod_labels)
        log_stream_name = f"{pod_name}_{self.pod_namespace}_{self.container_name}"
        response = self.aws_client.describe_log_streams(
            logGroupName=self.log_group_name, logStreamNamePrefix=log_stream_name
        )

        self.assertNotEqual(
            response["logStreams"],
            [],
            f"Required log stream not found in {response['logStreams']}"
        )

    def test_cloudwatch_logs_exists(self):
        cw_logs = self.get_latest_cw_logs()
        self.assertNotEqual(len(cw_logs), 0, "No CW logs found")

    def test_pod_logs_exists(self):
        pod_name = self.k8s.get_first_matching_pod_name(self.pod_namespace, self.pod_labels)
        pod_logs = self.k8s.get_latest_pod_logs(
            pod_name, self.container_name, self.pod_namespace, self.log_lines
        )
        self.assertNotEqual(len(pod_logs), 0, f"No pod logs found: {pod_name}")

    @test_retry
    def test_cw_logs_equal_pod_logs(self):
        pod_name = self.k8s.get_first_matching_pod_name(self.pod_namespace, self.pod_labels)
        pod_logs = self.k8s.get_latest_pod_logs(
            pod_name, self.container_name, self.pod_namespace, self.log_lines
        )
        cw_logs = self.get_latest_cw_logs()
        for line in pod_logs:
            self.assertIn(line, cw_logs, f"{line} not in CW logs")


if __name__ == "__main__":
    unittest.main()
