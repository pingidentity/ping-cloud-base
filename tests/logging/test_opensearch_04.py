import unittest
import subprocess
import time
import base64
import requests
import urllib3
from opensearchpy import OpenSearch
from opensearchpy.exceptions import NotFoundError
from k8s_utils import K8sUtils

NAMESPACE = "elastic-stack-logging"
LOGSTASH_LABEL = "app=logstash-elastic"
BOOTSTRAP_WAIT_TIMEOUT_SECONDS = 180
FULL_REBOOTSTRAP_WAIT_TIMEOUT_SECONDS = 480
POLL_INTERVAL_SECONDS = 3
BOOTSTRAP_STATUS_INDEX = "bootstrap-status"


class TestOpenSearchBootstrapResources(unittest.TestCase):
    """Verifies the opensearch-bootstrap init container (on
    logstash-elastic pods) completes successfully and that a full
    re-bootstrap recreates the resources it manages."""

    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        cls.port_forward_process = subprocess.Popen(
            ["kubectl", "port-forward", "service/opensearch-cluster-headless", "9200:9200",
             "-n", NAMESPACE], stdout=subprocess.PIPE
        )
        time.sleep(5)
        opensearch_creds_secret = cls.k8s.get_namespaced_secret(
            "opensearch-admin-credentials", NAMESPACE
        )
        if opensearch_creds_secret is None:
            raise Exception("Secret opensearch-admin-credentials not found. Is the logging stack deployed?")
        username = base64.b64decode(opensearch_creds_secret.data['username']).decode('utf-8')
        password = base64.b64decode(opensearch_creds_secret.data['password']).decode('utf-8')
        response = requests.get(f"https://localhost:{9200}", verify=False, auth=(username, password))
        if response.status_code == 200:
            print("Port-forward established successfully.")
        else:
            raise Exception("Port-forward failed. Exiting test.")
        cls.opensearch_client = OpenSearch(
            hosts=[{'host': 'localhost', 'port': 9200}],
            http_auth=(username, password),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=240
        )
        print("OpenSearch client created")

    @classmethod
    def tearDownClass(cls):
        cls.port_forward_process.terminate()

    def test_opensearch_bootstrap_succeeds(self):
        """Check the logstash-elastic pods are Ready. A pod only becomes Ready
        once every init container, including opensearch-bootstrap, has
        exited 0."""
        self.assertTrue(
            self.k8s.wait_for_all_pods_ready(LOGSTASH_LABEL, NAMESPACE, BOOTSTRAP_WAIT_TIMEOUT_SECONDS),
            f"logstash-elastic pods were not all Ready within {BOOTSTRAP_WAIT_TIMEOUT_SECONDS}s "
            f"(a pod is only Ready after its opensearch-bootstrap init container exits 0)."
        )

    ISM_POLICY_ID = "ping_7day_rollover_policy"
    ALERT_MONITOR_NAME = "PingFederate Connection Lost"

    def test_disaster_recovery_full_rebootstrap(self):
        """Delete bootstrap-status along with an index template, an ISM
        policy, and an alert monitor; restart one logstash-elastic pod; and
        check the full bootstrap() + osd.bootstrap() chain recreates all of
        them from scratch."""
        health = self.opensearch_client.cat.health(format="json")[0]
        status = health.get("status")
        print(f"Pre-check: cluster status is '{status}'")
        if status != "green":
            self.skipTest(
                f"Cluster status is '{status}'; a full bootstrap only runs on a GREEN cluster "
                f"(RED blocks bootstrap and repair, YELLOW leaves the restarted pod waiting for GREEN)."
            )

        template_name = "pf-transaction"
        try:
            template_snapshot = self.opensearch_client.indices.get_index_template(name=template_name)
        except Exception as e:
            self.fail(
                f"Sacrificial template '{template_name}' is missing before this test even "
                f"deleted it: {e}"
            )
        template_snapshot_body = template_snapshot["index_templates"][0]["index_template"]

        ism_policy_before = self.opensearch_client.transport.perform_request(
            "GET", f"/_plugins/_ism/policies/{self.ISM_POLICY_ID}"
        )
        if not ism_policy_before:
            self.fail(f"Sacrificial ISM policy '{self.ISM_POLICY_ID}' is missing before this "
                      f"test even deleted it")

        monitor_before = self._find_alert_monitor(self.ALERT_MONITOR_NAME)
        if monitor_before is None:
            self.fail(f"Sacrificial alert monitor '{self.ALERT_MONITOR_NAME}' is missing before "
                      f"this test even deleted it")

        print(f"Deleting template '{template_name}', ISM policy '{self.ISM_POLICY_ID}', "
              f"alert monitor '{self.ALERT_MONITOR_NAME}', and {BOOTSTRAP_STATUS_INDEX} "
              f"to simulate total resource loss")
        self.opensearch_client.indices.delete_index_template(name=template_name)
        self.opensearch_client.transport.perform_request(
            "DELETE", f"/_plugins/_ism/policies/{self.ISM_POLICY_ID}"
        )
        self.opensearch_client.plugins.alerting.delete_monitor(monitor_before["_id"])
        self.opensearch_client.indices.delete(index=BOOTSTRAP_STATUS_INDEX, ignore=[404])

        self.assertFalse(
            self.opensearch_client.indices.exists(index=BOOTSTRAP_STATUS_INDEX),
            f"{BOOTSTRAP_STATUS_INDEX} index still present after delete."
        )
        with self.assertRaises(NotFoundError, msg=f"Template '{template_name}' still present after delete."):
            self.opensearch_client.indices.get_index_template(name=template_name)
        with self.assertRaises(NotFoundError, msg=f"ISM policy '{self.ISM_POLICY_ID}' still present after delete."):
            self.opensearch_client.transport.perform_request(
                "GET", f"/_plugins/_ism/policies/{self.ISM_POLICY_ID}"
            )
        self.assertIsNone(
            self._find_alert_monitor(self.ALERT_MONITOR_NAME),
            f"Alert monitor '{self.ALERT_MONITOR_NAME}' still present after delete."
        )
        print("Confirmed all four resources are gone")

        print("Restarting one logstash-elastic pod; with bootstrap-status gone, "
              "entrypoint.py should take the full bootstrap()+osd.bootstrap() path "
              "instead of the lighter targeted repair")
        self._restart_logstash_pod_and_wait_for_bootstrap()

        # bootstrap-status is only recreated once the full chain finishes.
        self.assertTrue(
            self.opensearch_client.indices.exists(index=BOOTSTRAP_STATUS_INDEX),
            f"{BOOTSTRAP_STATUS_INDEX} was not recreated — the full bootstrap chain did not complete."
        )

        repaired_template = self.opensearch_client.indices.get_index_template(name=template_name)
        self.assertEqual(
            repaired_template["index_templates"][0]["index_template"], template_snapshot_body,
            f"Recreated template '{template_name}' does not match its pre-deletion snapshot."
        )

        # ISM policy: compare _ism_fields; monitor: compare MONITOR_COMPARE_FIELDS.
        ism_policy_after = self.opensearch_client.transport.perform_request(
            "GET", f"/_plugins/_ism/policies/{self.ISM_POLICY_ID}"
        )
        self.assertEqual(
            self._ism_fields(ism_policy_after), self._ism_fields(ism_policy_before),
            f"Recreated ISM policy '{self.ISM_POLICY_ID}' does not match its pre-deletion snapshot."
        )

        self.assertEqual(
            self._monitor_fields(self._find_alert_monitor(self.ALERT_MONITOR_NAME)),
            self._monitor_fields(monitor_before),
            f"Recreated alert monitor '{self.ALERT_MONITOR_NAME}' does not match its pre-deletion snapshot."
        )
        print("Template, ISM policy, and alert monitor all match their pre-deletion snapshots")

    def _ism_fields(self, response):
        """The policy's states and ism_template are compared. But each ism_template entry's last_updated_time
        is left out because it changes when the policy is recreated."""
        policy = response["policy"]
        return {
            "states": policy.get("states"),
            "ism_template": [
                {k: v for k, v in t.items() if k != "last_updated_time"}
                for t in policy.get("ism_template", [])
            ],
        }

    MONITOR_COMPARE_FIELDS = ("name", "enabled", "schedule", "inputs")

    def _monitor_fields(self, hit):
        """The monitor's fields listed in MONITOR_COMPARE_FIELDS, or None if there is no monitor."""
        return {f: hit["_source"].get(f) for f in self.MONITOR_COMPARE_FIELDS} if hit else None

    def _find_alert_monitor(self, monitor_name):
        """Return the alert monitor search hit (with _id and _source) whose
        name matches, or None if not found."""
        response = self.opensearch_client.plugins.alerting.search_monitor(
            {"query": {"match_phrase": {"monitor.name": monitor_name}}}
        )
        for hit in response.get("hits", {}).get("hits", []):
            if hit.get("_source", {}).get("name") == monitor_name:
                return hit
        return None

    def _restart_logstash_pod_and_wait_for_bootstrap(self):
        """Delete one Ready logstash-elastic pod, wait for all pods to be Ready
        (a pod is only Ready after opensearch-bootstrap exits 0), then wait for
        bootstrap-status, which is only recreated once the full bootstrap finishes."""
        ready_pods = self.k8s.list_ready_running_pods_by_label(LOGSTASH_LABEL, NAMESPACE)
        self.assertTrue(ready_pods, f"No Ready pod with label {LOGSTASH_LABEL} to restart.")
        pod_name = ready_pods[0]
        print(f"Deleting pod '{pod_name}'; StatefulSet will recreate it with the same name")
        deadline = time.time() + FULL_REBOOTSTRAP_WAIT_TIMEOUT_SECONDS
        self.k8s.core_client.delete_namespaced_pod(name=pod_name, namespace=NAMESPACE)

        self.k8s.wait_for_all_pods_ready(LOGSTASH_LABEL, NAMESPACE, FULL_REBOOTSTRAP_WAIT_TIMEOUT_SECONDS)

        # The pod wait can return early on the old terminating pod, so gate on the actual result.
        while not self.opensearch_client.indices.exists(index=BOOTSTRAP_STATUS_INDEX):
            self.assertLess(
                time.time(), deadline,
                f"{BOOTSTRAP_STATUS_INDEX} was not recreated within {FULL_REBOOTSTRAP_WAIT_TIMEOUT_SECONDS}s "
                f"of restarting '{pod_name}' — the full bootstrap chain did not complete."
            )
            time.sleep(POLL_INTERVAL_SECONDS)

    # (backend_role, OpenSearch role) pairs, from p1as-eng-docker
    # pingcloud-services/p14c-integration/src/templates/opensearch/roles_mapping.yml.
    EXPECTED_ROLE_MAPPINGS = (
        ("admin", "all_access"),
        ("kibanauser", "kibana_user"),
        ("logstash", "logstash"),
        ("logstash", "logstash_write"),
        ("opendistro_security_anonymous_backendrole", "read_prometheus"),
        ("os-configteam", "kibana_user"),
        ("os-configteam", "customer_role"),
        ("os-configteam", "alerting_full_access"),
        ("os-configteam", "reports_full_access"),
        ("os-configteam", "query_save_export"),
        ("os-ping", "all_access"),
        ("os-ping", "reports_full_access"),
        ("os-ping", "query_save_export"),
    )

    # (user, OpenSearch role) pairs for the roles mapped via `users:` instead of `backend_roles:`.
    EXPECTED_USER_MAPPINGS = (
        ("kibanaserver", "kibana_server"),
        ("bootstrap", "bootstrap"),
    )

    def test_security_roles_mapped(self):
        """Check each expected backend role / user is mapped into its
        OpenSearch role via the rolesmapping API."""
        response = self.opensearch_client.transport.perform_request(
            "GET", "/_plugins/_security/api/rolesmapping"
        )
        print(f"Found {len(response)} role mapping(s)")
        for required_backend_role, required_role in self.EXPECTED_ROLE_MAPPINGS:
            with self.subTest(backend_role=required_backend_role, os_role=required_role):
                self.assertIn(
                    required_role, response,
                    f"OpenSearch role '{required_role}' has no role mapping configured."
                )
                backend_roles = response[required_role].get("backend_roles", [])
                self.assertIn(
                    required_backend_role, backend_roles,
                    f"Backend role '{required_backend_role}' is not mapped to OpenSearch role "
                    f"'{required_role}' (mapped backend_roles: {backend_roles})."
                )
                print(f"Backend role '{required_backend_role}' correctly mapped to OpenSearch role '{required_role}'")

        for required_user, required_role in self.EXPECTED_USER_MAPPINGS:
            with self.subTest(user=required_user, os_role=required_role):
                self.assertIn(
                    required_role, response,
                    f"OpenSearch role '{required_role}' has no role mapping configured."
                )
                users = response[required_role].get("users", [])
                self.assertIn(
                    required_user, users,
                    f"User '{required_user}' is not mapped to OpenSearch role "
                    f"'{required_role}' (mapped users: {users})."
                )
                print(f"User '{required_user}' correctly mapped to OpenSearch role '{required_role}'")


if __name__ == '__main__':
    unittest.main()
