import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FLUENTBIT_CONFIG_DIR = REPO_ROOT / "k8s-configs/cluster-tools/base/logging/fluentbit/configs"


def _blocks(config: str, section: str):
    return re.findall(rf"^\[{section}\]\n(.*?)(?=^\[|\Z)", config, flags=re.M | re.S)


class TestFluentBitStaticRouting(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_conf = (FLUENTBIT_CONFIG_DIR / "pipeline-core.conf").read_text()
        cls.outputs_conf = (FLUENTBIT_CONFIG_DIR / "pipeline-outputs.conf").read_text()

    def _input_block(self, tag: str, path: str):
        for block in _blocks(self.core_conf, "INPUT"):
            if f"Tag                 {tag}" in block and f"Path                {path}" in block:
                return block
        self.fail(f"Missing Fluent Bit input for tag={tag} path={path}")

    def _output_block(self, alias: str):
        for block in _blocks(self.outputs_conf, "OUTPUT"):
            if f"Alias               {alias}" in block:
                return block
        self.fail(f"Missing Fluent Bit output alias={alias}")

    def test_p14c_ping_cloud_logs_are_preserved_for_main_and_s3(self):
        for tag in ("elk.kube.general.*", "elk.s3.general.*"):
            block = self._input_block(tag, "/var/log/containers/*_ping-cloud_*.log")
            self.assertIn("Exclude_Path", block)
            self.assertIn("*pingcloud-metadata*.log", block)
            self.assertNotIn("p14c-", block)

        self._input_block("s3.kube.*", "/var/log/containers/p14c-*.log")

    def test_kube_proxy_logs_are_preserved_for_main_and_s3(self):
        # kube-proxy is not a Ping app log, but log-based alerts depend on it,
        # so it must continue routing through the main/OpenSearch pipeline.
        self._input_block("elk.kube.general.*", "/var/log/containers/*_kube-system_kube-proxy-*.log")
        self._input_block("s3.kube.*", "/var/log/containers/*_kube-system_*.log")

    def test_main_and_s3_app_outputs_match_expected_tags(self):
        main_block = self._output_block("app_opensearch_out")
        self.assertIn("Match               elk.kube.*", main_block)
        self.assertIn("Host                logstash-elastic.elastic-stack-logging", main_block)
        self.assertIn("Port                8080", main_block)

        s3_block = self._output_block("app_s3_archive_out")
        self.assertIn("Match               elk.s3.*", s3_block)
        self.assertIn("Host                logstash-elastic-s3.elastic-stack-logging", s3_block)
        self.assertIn("Port                8081", s3_block)


if __name__ == "__main__":
    unittest.main()
