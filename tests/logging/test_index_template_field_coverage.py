import base64
import json
import os
import subprocess
import time
import unittest
import urllib3

from opensearchpy import OpenSearch

OPENSEARCH_NAMESPACE = "elastic-stack-logging"
OPENSEARCH_SERVICE = "opensearch"
OPENSEARCH_PORT = 9200
OPENSEARCH_CREDENTIALS_SECRET = "opensearch-admin-credentials"

# general and logstash are catch-all templates that receive heterogeneous logs
# with no fixed schema — skipping field coverage checks for both.
SKIP_TEMPLATES = {"general", "logstash"}

# Fields known to be missing from specific index templates pending a fix.
# Remove entries once the corresponding template is updated.
KNOWN_MISSING_FIELDS = {
    "pds-errors": {"vm.swappiness"},
    "pds-server": {"class", "id"},
    "ingress-access": {"log"},
}

# OS adds these metadata fields to every document at index time; they are not
# part of the log payload and do not need to be declared in the template.
OS_INTERNAL_FIELDS = {"_id", "_index", "_score", "_type"}

# When set, templates are loaded from this local directory instead of from the
# OpenSearch cluster. Useful for running against a port-forwarded cluster with
# a checked-out copy of the templates.
INDEX_TEMPLATES_DIR = os.environ.get("INDEX_TEMPLATES_DIR")


def _get_mapped_fields(template_body: dict) -> dict:
    """Return a {dot-notated-path: type-or-None} dict for all fields in a template.

    Recurses into nested `properties` blocks. Intermediate object fields with
    no explicit type get `None`. The dict is used both for membership checks
    (`field in mapped_fields`) and to identify `geo_point` fields so their
    `lat`/`lon` document sub-paths can be excluded from unmapped-field checks.
    """
    def _recurse(props: dict, prefix: str) -> dict:
        result = {}
        for k, v in props.items():
            full = f"{prefix}.{k}" if prefix else k
            result[full] = v.get("type")
            if "properties" in v:
                result.update(_recurse(v["properties"], full))
        return result

    props = (
        template_body.get("template", {})
        .get("mappings", {})
        .get("properties", {})
    )
    return _recurse(props, "")


def _flatten_doc_fields(source: dict, prefix: str = "") -> set:
    """Return every dot-notated field path present in a document source dict.

    Recurses into nested dicts so that `{"kubernetes": {"pod_name": "x"}}`
    produces both `"kubernetes"` and `"kubernetes.pod_name"`.  This mirrors
    the output of `_get_mapped_fields` so the two sets can be compared
    directly.
    """
    fields = set()
    for k, v in source.items():
        full_key = f"{prefix}.{k}" if prefix else k
        fields.add(full_key)
        if isinstance(v, dict):
            fields |= _flatten_doc_fields(v, full_key)
    return fields


def _load_templates_from_cluster(os_client: OpenSearch) -> list:
    """Fetch all index templates from the OpenSearch cluster and return a
    normalised list of `(template_name, index_pattern, mapped_fields)` tuples.

    Uses `GET /_index_template` (composite templates API).  Templates in
    `SKIP_TEMPLATES` are excluded.  If a template defines multiple
    `index_patterns`, the first pattern is used for querying documents.
    """
    response = os_client.indices.get_index_template()
    results = []
    for entry in response.get("index_templates", []):
        name = entry["name"]
        if name in SKIP_TEMPLATES:
            continue
        body = entry["index_template"]
        patterns = body.get("index_patterns", [])
        if not patterns:
            continue
        mapped_fields = _get_mapped_fields(body)
        results.append((name, patterns[0], mapped_fields))
    return results


def _load_templates_from_dir(templates_dir: str) -> list:
    """Load index templates from a local directory of JSON files and return a
    normalised list of `(template_name, index_pattern, mapped_fields)` tuples.

    Each `.json` file is expected to match the same schema used by the
    OpenSearch `PUT /_index_template` API.  Templates whose stem (filename
    without extension) is in `SKIP_TEMPLATES` are excluded.  Useful for
    running the test locally against a port-forwarded cluster when a checked-out
    copy of the templates is available; set `INDEX_TEMPLATES_DIR` in the
    environment to activate this path.
    """
    from pathlib import Path

    results = []
    for path in sorted(Path(templates_dir).glob("*.json")):
        if path.stem in SKIP_TEMPLATES:
            continue
        with path.open() as f:
            body = json.load(f)
        patterns = body.get("index_patterns", [])
        if not patterns:
            continue
        mapped_fields = _get_mapped_fields(body)
        results.append((path.stem, patterns[0], mapped_fields))
    return results


class TestIndexTemplateFieldCoverage(unittest.TestCase):
    """Verify that every field appearing in recent log documents is declared in
    the corresponding index template mapping.

    For each index template, the test queries the last 1 hour of documents
    from the matching index pattern and asserts that no document contains a
    field absent from the template's `properties` mapping.  Undeclared fields
    indicate either stale templates (a new field was added to the log payload
    but not to the template) or unexpected data reaching OpenSearch.

    Templates are sourced from the live OpenSearch cluster by default
    (`GET /_index_template`).  Set the `INDEX_TEMPLATES_DIR` environment
    variable to load templates from a local directory instead, which is useful
    when running against a port-forwarded cluster with a checked-out copy.
    """

    @classmethod
    def setUpClass(cls):
        """Set up the OpenSearch client via kubectl port-forward.

        Reads credentials from the `opensearch-admin-credentials` secret in
        the `elastic-stack-logging` namespace, then loads all index templates
        from the cluster (or from `INDEX_TEMPLATES_DIR` if set).
        """
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        cls.port_forward_process = subprocess.Popen(
            [
                "kubectl", "port-forward",
                f"service/{OPENSEARCH_SERVICE}",
                f"{OPENSEARCH_PORT}:{OPENSEARCH_PORT}",
                "-n", OPENSEARCH_NAMESPACE,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        time.sleep(5)

        from k8s_utils import K8sUtils
        k8s = K8sUtils()
        secret = k8s.get_namespaced_secret(
            OPENSEARCH_CREDENTIALS_SECRET, OPENSEARCH_NAMESPACE
        )
        username = base64.b64decode(secret.data["username"]).decode()
        password = base64.b64decode(secret.data["password"]).decode()

        cls.os_client = OpenSearch(
            hosts=[{"host": "localhost", "port": OPENSEARCH_PORT}],
            http_auth=(username, password),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=60,
        )

        if INDEX_TEMPLATES_DIR:
            cls.templates = _load_templates_from_dir(INDEX_TEMPLATES_DIR)
        else:
            cls.templates = _load_templates_from_cluster(cls.os_client)

    @classmethod
    def tearDownClass(cls):
        """Terminate the kubectl port-forward process."""
        cls.port_forward_process.terminate()

    def _fetch_recent_docs(self, index_pattern: str, size: int = 100) -> list:
        """Query `index_pattern` for documents timestamped in the last 1 hour.

        Returns a list of `_source` dicts.  Returns an empty list if the index
        does not exist or contains no documents in the window, so the caller can
        decide to skip rather than fail.
        """
        query = {
            "size": size,
            "query": {
                "range": {
                    "@timestamp": {
                        "gte": "now-1h",
                        "lte": "now",
                    }
                }
            },
            "sort": [{"@timestamp": {"order": "desc"}}],
        }
        try:
            response = self.os_client.search(index=index_pattern, body=query)
            return [hit["_source"] for hit in response["hits"]["hits"]]
        except Exception as e:
            if "index_not_found" in str(e).lower() or "no such index" in str(e).lower():
                return []
            raise

    def test_no_unmapped_fields_in_recent_docs(self):
        """Assert that no document field is absent from the template mapping.

        Iterates every loaded template, fetches up to 100 documents from the
        last 1 hour, and compares each document's flattened field paths
        against the template's declared `properties`.  OpenSearch internal
        metadata fields (`_id`, `_index`, etc.) are excluded from the
        comparison.

        Indices with no recent documents are skipped rather than failed, since
        low-traffic indices (e.g. `pd-expensive-write-ops`) may legitimately
        have no activity in a short window.
        """
        self.assertTrue(self.templates, "No templates loaded — check cluster connectivity or INDEX_TEMPLATES_DIR")

        for template_name, index_pattern, mapped_fields in self.templates:
            with self.subTest(template=template_name, index=index_pattern):
                docs = self._fetch_recent_docs(index_pattern)

                if not docs:
                    print(f"\nSKIP {template_name}: no documents in '{index_pattern}' in the last 1 hour", flush=True)
                    continue

                # Paths mapped as geo_point: Logstash writes location as
                # {"lat": x, "lon": y}, so documents contain .lat/.lon sub-keys.
                # Those are valid geo_point inputs — not missing template fields.
                geo_point_fields = {p for p, t in mapped_fields.items() if t == "geo_point"}
                geo_point_subpaths = {f"{p}.lat" for p in geo_point_fields} | \
                                     {f"{p}.lon" for p in geo_point_fields}

                known_missing = KNOWN_MISSING_FIELDS.get(template_name, set())
                unmapped_per_doc = []
                for doc in docs:
                    doc_fields = _flatten_doc_fields(doc)
                    unmapped = doc_fields - mapped_fields.keys() - OS_INTERNAL_FIELDS - geo_point_subpaths - known_missing
                    if unmapped:
                        unmapped_per_doc.append(unmapped)

                if unmapped_per_doc:
                    all_unmapped = sorted(set().union(*unmapped_per_doc))
                    msg = (
                        f"{template_name} ({index_pattern}): {len(unmapped_per_doc)}/{len(docs)} "
                        f"documents contain fields not declared in the template mapping:\n"
                        + "\n".join(f"  - {f}" for f in all_unmapped)
                    )
                    print(f"\n{msg}", flush=True)
                    self.fail(msg)


if __name__ == "__main__":
    unittest.main()
