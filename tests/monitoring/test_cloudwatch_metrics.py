import unittest
import os
import json
import boto3
from datetime import datetime, timedelta
from json import JSONDecodeError


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
        events_seen = 0
        parse_errors = 0
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
                events_seen += 1
                try:
                    log_data = json.loads(event.get("message", "{}"))
                except JSONDecodeError:
                    parse_errors += 1
                    continue
                for metric in self.metrics:
                    if metric in log_data:
                        found_metrics[metric] = True

            if all(found_metrics.values()):
                return {
                    "found_metrics": found_metrics,
                    "events_seen": events_seen,
                    "parse_errors": parse_errors,
                }

            next_token = response.get("nextForwardToken")

            if (datetime.now() - start_time) > max_duration or not next_token:
                break

        return {
            "found_metrics": found_metrics,
            "events_seen": events_seen,
            "parse_errors": parse_errors,
        }

    def test_metrics_in_logs(self):
        log_streams = self.get_all_log_streams()
        stream_diagnostics = {}
        found_metrics = {metric: False for metric in self.metrics}

        for log_stream_name in log_streams:
            result = self.check_metrics_in_logs(log_stream_name)
            found_metrics = result["found_metrics"]
            stream_diagnostics[log_stream_name] = result
            if all(found_metrics.values()):
                break

        missing = [metric for metric, present in found_metrics.items() if not present]
        sampled_streams = list(stream_diagnostics.items())[:5]
        sampled_diag = [
            {
                "stream": stream,
                "missing_metrics": [m for m, ok in data["found_metrics"].items() if not ok],
                "events_seen": data["events_seen"],
                "parse_errors": data["parse_errors"],
            }
            for stream, data in sampled_streams
        ]

        self.assertTrue(
            all(found_metrics.values()),
            (
                f"Not all required metrics were found in the logs for log group "
                f"'{self.log_group_name}'. Missing metrics: {missing}. "
                f"Checked {len(stream_diagnostics)} stream(s). "
                f"Sample stream diagnostics: {sampled_diag}"
            ),
        )


if __name__ == "__main__":
    unittest.main()
