import unittest
import os
import json
import boto3
from datetime import datetime, timedelta


class TestCloudWatchLogs(unittest.TestCase):
    aws_region = os.environ.get("AWS_REGION", "us-west-2")
    k8s_cluster_name = os.environ["CLUSTER_NAME"]

    aws_client = boto3.client("logs", region_name=aws_region)
    log_group_name = f"/aws/containerinsights/{k8s_cluster_name}/prometheus"
    metrics = ["kube_endpoint_address_available", "kube_node_status_condition"]

    def check_log_group_exists(self):
        response = self.aws_client.describe_log_groups(
            logGroupNamePrefix=self.log_group_name
        )
        log_groups = response.get("logGroups", [])
        self.assertTrue(len(log_groups) > 0, f"Log group '{self.log_group_name}' does not exist.")

    def get_all_log_streams(self):
        self.check_log_group_exists()
        
        response = self.aws_client.describe_log_streams(
            logGroupName=self.log_group_name, orderBy="LastEventTime", descending=True
        )
        log_streams = response.get("logStreams", [])
        self.assertTrue(len(log_streams) > 0, "No log streams found in the log group.")
        return [stream["logStreamName"] for stream in log_streams]

    def check_metrics_in_logs(self, log_stream_name):
        dt_now_ms = round(datetime.now().timestamp() * 1000)
        dt_past_ms = round((datetime.now() - timedelta(minutes=5)).timestamp() * 1000)

        found_metrics = {metric: False for metric in self.metrics}
        next_token = None
        start_time = datetime.now()
        max_duration = timedelta(minutes=2)

        while True:
            kwargs = {
                "logGroupName": self.log_group_name,
                "logStreamName": log_stream_name,
                "startTime": dt_past_ms,
                "endTime": dt_now_ms,
            }

            if next_token:
                kwargs["nextToken"] = next_token

            response = self.aws_client.get_log_events(**kwargs)

            for event in response.get("events", []):
                log_data = json.loads(event.get("message", "{}"))
                for metric in self.metrics:
                    if metric in log_data:
                        found_metrics[metric] = True

            if all(found_metrics.values()):
                return found_metrics

            next_token = response.get("nextForwardToken")

            if (datetime.now() - start_time) > max_duration or not next_token:
                break

        return found_metrics

    def test_metrics_in_logs(self):
        log_streams = self.get_all_log_streams()

        for log_stream_name in log_streams:
            found_metrics = self.check_metrics_in_logs(log_stream_name)
            if all(found_metrics.values()):
                break

        self.assertTrue(
            all(found_metrics.values()),
            f"Not all required metrics were found in the logs for log group '{self.log_group_name}'.",
        )


if __name__ == "__main__":
    unittest.main()
