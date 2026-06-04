import re
import unittest
import subprocess
import time
import base64
import requests
import urllib3
from opensearchpy import OpenSearch
from k8s_utils import K8sUtils

class TestOpenSearchLogs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        # Port-forward the OpenSearch service (opensearch-cluster-headless)
        cls.port_forward_process = subprocess.Popen(
            ["kubectl", "port-forward", "service/opensearch-cluster-headless", "9200:9200", 
             "-n", "elastic-stack-logging"], stdout=subprocess.PIPE
        )
         # Give port-forwarding time to establish
        time.sleep(5) 
        # Get OpenSearch Admin user/password from the secret in the 'opensearch-admin-credentials' secret
        opensearch_creds_secret = cls.k8s.get_namespaced_secret(
            "opensearch-admin-credentials", "elastic-stack-logging"
        )
        username = base64.b64decode(opensearch_creds_secret.data['username']).decode('utf-8')
        password = base64.b64decode(opensearch_creds_secret.data['password']).decode('utf-8')
        print(username, password)
        response = requests.get(f"https://localhost:{9200}", verify=False, auth=(username, password))
        if response.status_code == 200:
            print("Port-forward established successfully.")
        else:
            raise Exception("Port-forward failed. Exiting test.")
        # Create OpenSearch client
        cls.opensearch_client = OpenSearch(
            hosts=[{'host': 'localhost', 'port': 9200}],
            http_auth=(username, password),
            use_ssl=True, 
            verify_certs=False,
            ssl_show_warn = False,
            timeout=240 # in seconds
        )
        print("OpenSearch client created")

    @classmethod
    def tearDownClass(cls):
        # Terminate the port-forward process after the test suite runs
        cls.port_forward_process.terminate()

    def test_fluentbit_ingestion_field_timestamp(self):
        # Search logs in OpenSearch index template
        index_name = "logstash-*"  
        query = {
            "query": {
                "match_all": {}
            },
            "_source": ["fluentbit_ingest_timestamp"]
        }
        # Fetch indexes by regex
        response = self.opensearch_client.search(index=index_name, body=query)

        # Verify that the fluentbit_ingestion_field has a time in milliseconds
        for hit in response['hits']['hits']:
            timestamp_field = hit['_source'].get('fluentbit_ingest_timestamp')
            self.assertIsNotNone(timestamp_field, "fluentbit_ingest_timestamp is missing")
             # Validate timestamp format matches (YYYY-MM-DDTHH:MM:SS.SSSSSSSSSZ)
             # Note milliseconds might be in range of 1-9 digits
            timestamp_regex = r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z$'
            match = re.match(timestamp_regex, timestamp_field)
            self.assertIsNotNone(match,
                f"fluentbit_ingestion_field is not a valid timestamp: {timestamp_field}"
            )
    def assert_index_receives_logs(self, index_pattern: str, expected_fields: list[str]):
        query = {
            "query": {"match_all": {}},
            "_source": expected_fields,
            "size": 10,
        }
        response = self.opensearch_client.search(index=index_pattern, body=query)
        hits = response["hits"]["hits"]

        self.assertGreater(
            len(hits), 0,
            f"No documents found in {index_pattern}. Logs are not reaching OpenSearch.",
        )

        for hit in hits:
            source = hit["_source"]
            missing = [f for f in expected_fields if f not in source]
            self.assertEqual(
                missing, [],
                f"{index_pattern} document is missing expected fields {missing}. Document: {source}",
            )

    def assert_no_parse_failures(self, index_pattern: str):
        query = {
            "query": {
                "terms": {
                    "tags": ["_grokparsefailure", "_jsonparsefailure"],
                }
            },
            "_source": ["tags", "log", "message"],
            "size": 10,
        }
        response = self.opensearch_client.search(index=index_pattern, body=query)
        hits = response["hits"]["hits"]

        self.assertEqual(
            len(hits), 0,
            f"Found {len(hits)} document(s) in {index_pattern} with parse failure tags "
            f"(_grokparsefailure or _jsonparsefailure):\n"
            + "\n".join(str(h["_source"]) for h in hits),
        )

    def test_pdg_access_logs(self):
        self.assert_index_receives_logs(
            index_pattern="pdg-access-*",
            expected_fields=[
                "client", "method", "url", "httpVersion",
                "responseCode", "bodySentBytes", "userAgent",
                "app_timestamp",
            ],
        )
        self.assert_no_parse_failures("pdg-access-*")


if __name__ == '__main__':
    unittest.main()
