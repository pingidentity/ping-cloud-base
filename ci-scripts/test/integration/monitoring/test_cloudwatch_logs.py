import unittest
import os
import json
import boto3

import k8s_utils


class TestCloudWatchLogs(k8s_utils.K8sUtils):
    log_lines = os.getenv("LOG_LINES_TO_TEST", 10)

    aws_region = os.getenv("AWS_REGION", "us-west-2")
    aws_client = boto3.client("logs", region_name=aws_region)

    # Change the pod_name, pod_namespace, and container_name to use this test with another application.
    pod_name = "es-cluster-hot-0"
    pod_namespace = "elastic-stack-logging"
    container_name = "elasticsearch"
    k8s_cluster_name = os.getenv("TENANT_NAME")
    log_group_name = f"/aws/containerinsights/{k8s_cluster_name}/application"
    log_stream_name = f"{pod_name}_{pod_namespace}_{container_name}.cw_out"

    def get_latest_cw_logs(self):
        cw_logs = []
        response = self.aws_client.get_log_events(
            logGroupName=self.log_group_name,
            logStreamName=self.log_stream_name,
            limit=int(self.log_lines),
            startFromHead=False,
        )

        for event in response["events"]:
            cw_logs.append(json.loads(event["message"])["log"].replace("\n", ""))

        return cw_logs

    def test_cloudwatch_log_group_exists(self):
        response = self.aws_client.describe_log_groups(
            logGroupNamePrefix=self.log_group_name
        )

        self.assertNotEqual(response["logGroups"], [], "Required log groups not found")

    def test_cloudwatch_log_stream_exists(self):
        response = self.aws_client.describe_log_streams(
            logGroupName=self.log_group_name, logStreamNamePrefix=self.log_stream_name
        )

        self.assertNotEqual(response["logStreams"], [], "Required log stream not found")

    def test_cloudwatch_logs_exists(self):
        cw_logs = self.get_latest_cw_logs()
        self.assertNotEqual(len(cw_logs), 0, "No CW logs found")

    def test_pod_logs_exists(self):
        pod_logs = self.get_latest_pod_logs(self.pod_name, self.container_name, self.pod_namespace, self.log_lines)
        print(pod_logs)
        self.assertNotEqual(len(pod_logs), 0, "No pod logs found")

    def test_cw_logs_equal_pod_logs(self):
        cw_logs = self.get_latest_cw_logs()
        pod_logs = self.get_latest_pod_logs(self.pod_name, self.container_name, self.pod_namespace, self.log_lines)
        self.assertEqual(cw_logs, pod_logs, "Logs are not the same")


if __name__ == "__main__":
    unittest.main()
