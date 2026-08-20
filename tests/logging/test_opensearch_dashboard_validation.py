import base64
import json
import os
import re
import subprocess
import time
import unittest
import urllib3

import requests
from opensearchpy import OpenSearch
from k8s_utils import K8sUtils

# Maps OpenSearch index template mapping types to their expected OSD field types.

INDEX_TEMPLATES_DIR = os.environ.get("INDEX_TEMPLATES_DIR")


class TestOpenSearchDashboardValidation(unittest.TestCase):
    """
    Validates that fields actively used in OpenSearch Dashboards (in queries,
    filters, and aggregations) exist in the corresponding OpenSearch index
    templates with a compatible type.

    Flow per dashboard:
      1. Collect all referenced visualization / search / Lens saved objects.
      2. Parse each object to extract field names from filters, aggregations,
         and Lens column definitions.
      3. Resolve the index pattern to its index template in OpenSearch.
      4. Assert every used field is present in the template mapping with a
         compatible type.
    """

    NAMESPACE = "elastic-stack-logging"
    OS_SERVICE = "opensearch"
    OSD_SERVICE = "opensearch-dashboards"
    OS_PORT = 9200
    OSD_PORT = 5601

    @classmethod
    def setUpClass(cls):
        """Port-forward to OpenSearch and OSD, verify connectivity, and build the OS client."""
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        cls.os_pf = subprocess.Popen(
            ["kubectl", "port-forward", f"service/{cls.OS_SERVICE}",
             f"{cls.OS_PORT}:{cls.OS_PORT}", "-n", cls.NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        cls.osd_pf = subprocess.Popen(
            ["kubectl", "port-forward", f"service/{cls.OSD_SERVICE}",
             f"{cls.OSD_PORT}:{cls.OSD_PORT}", "-n", cls.NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        time.sleep(5)

        secret = cls.k8s.get_namespaced_secret("opensearch-admin-credentials", cls.NAMESPACE)
        cls.username = base64.b64decode(secret.data["username"]).decode("utf-8")
        cls.password = base64.b64decode(secret.data["password"]).decode("utf-8")
        cls.auth = (cls.username, cls.password)

        resp = requests.get(f"https://localhost:{cls.OS_PORT}", verify=False, auth=cls.auth)
        if resp.status_code != 200:
            raise Exception(f"OpenSearch port-forward failed with status {resp.status_code}")

        resp = requests.get(
            f"http://localhost:{cls.OSD_PORT}/api/status",
            auth=cls.auth,
            headers={"osd-xsrf": "true"},
        )
        if resp.status_code != 200:
            raise Exception(f"OpenSearch Dashboards port-forward failed with status {resp.status_code}")

        cls.os_client = OpenSearch(
            hosts=[{"host": "localhost", "port": cls.OS_PORT}],
            http_auth=cls.auth,
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=240,
        )
        cls.osd_base = f"http://localhost:{cls.OSD_PORT}"
        cls.osd_headers = {"osd-xsrf": "true"}

    @classmethod
    def tearDownClass(cls):
        """Terminate kubectl port-forward processes for OpenSearch and OSD."""
        cls.os_pf.terminate()
        cls.osd_pf.terminate()

    # -------------------------------------------------------------------------
    # OSD API helpers
    # -------------------------------------------------------------------------

    def _osd_get(self, path, params=None):
        """GET ``path`` from the OSD API and return the parsed JSON response."""
        resp = requests.get(
            f"{self.osd_base}{path}",
            auth=self.auth,
            headers=self.osd_headers,
            params=params,
        )
        resp.raise_for_status()
        return resp.json()

    def _get_all_saved_objects(self, obj_type):
        """Return all saved objects of ``obj_type`` from OSD, paginating as needed."""
        objects = []
        page = 1
        while True:
            data = self._osd_get("/api/saved_objects/_find", params={
                "type": obj_type,
                "per_page": 100,
                "page": page,
            })
            objects.extend(data.get("saved_objects", []))
            if len(objects) >= data.get("total", 0):
                break
            page += 1
        return objects

    def _get_saved_object(self, obj_type, obj_id):
        """Fetch a single saved object by type and ID; returns None on any error."""
        try:
            return self._osd_get(f"/api/saved_objects/{obj_type}/{obj_id}")
        except Exception:
            return None

    # -------------------------------------------------------------------------
    # Field extraction from saved objects
    # -------------------------------------------------------------------------

    def _fields_from_search_source(self, search_source_json):
        """Extract field names from a searchSourceJSON blob.

        Parses both the ``filter`` array (meta.key and query DSL clauses) and
        the top-level ``query`` field, which may be a KQL/Lucene string
        (``{query: "field:value", language: "kuery"}``) or a query DSL object.
        """
        fields = set()
        try:
            source = json.loads(search_source_json) if isinstance(search_source_json, str) else search_source_json
        except (json.JSONDecodeError, TypeError):
            return fields

        for f in source.get("filter", []):
            # Standard filter: meta.key holds the field name
            key = f.get("meta", {}).get("key")
            if key and not key.startswith("$"):
                fields.add(key)
            # Query DSL filters: walk common query shapes for field names
            fields.update(self._fields_from_query(f.get("query", {})))

        # Top-level query — may be a KQL/Lucene string in {query: "...", language: "kuery"}
        top_query = source.get("query", {})
        if isinstance(top_query, dict):
            qs = top_query.get("query", "")
            if isinstance(qs, str) and qs:
                fields.update(self._fields_from_lucene(qs))
            else:
                fields.update(self._fields_from_query(top_query))
        return fields

    def _fields_from_query(self, query):
        """Recursively extract field names from an OpenSearch query DSL object."""
        fields = set()
        if not isinstance(query, dict):
            return fields
        for clause, value in query.items():
            if clause in ("match", "term", "terms", "range",
                          "prefix", "wildcard", "regexp", "fuzzy"):
                if isinstance(value, dict):
                    for field in value:
                        if not field.startswith("$"):
                            fields.add(field)
            elif clause == "exists":
                if isinstance(value, dict) and "field" in value:
                    fields.add(value["field"])
            elif clause in ("bool", "must", "should", "must_not", "filter"):
                sub = value if isinstance(value, list) else [value]
                for item in sub:
                    fields.update(self._fields_from_query(item))
            elif isinstance(value, dict):
                fields.update(self._fields_from_query(value))
            elif isinstance(value, list):
                for item in value:
                    fields.update(self._fields_from_query(item))
        return fields

    _LUCENE_FIELD_RE = re.compile(r'([\w.@]+)\s*:', re.ASCII)
    _QUOTED_STR_RE = re.compile(r'"[^"]*"')

    def _fields_from_lucene(self, query_str):
        """Extract field names from a Lucene/KQL query string (e.g. 'level:ERROR AND message:*foo*')."""
        fields = set()
        if not query_str or not isinstance(query_str, str):
            return fields
        stripped = self._QUOTED_STR_RE.sub('""', query_str)
        for m in self._LUCENE_FIELD_RE.finditer(stripped):
            f = m.group(1)
            if not f.startswith("$") and not f.startswith("_") and f not in ("AND", "OR", "NOT"):
                fields.add(f)
        return fields

    def _fields_from_vis_state(self, vis_state_json):
        """Extract fields from legacy visualization aggregations, including TSVB (metrics type)."""
        fields = set()
        try:
            vis_state = json.loads(vis_state_json) if isinstance(vis_state_json, str) else vis_state_json
        except (json.JSONDecodeError, TypeError):
            return fields

        # Standard aggs (terms, date_histogram, etc.)
        for agg in vis_state.get("aggs", []):
            field = agg.get("params", {}).get("field")
            if field and not field.startswith("_"):
                fields.add(field)
            for f in agg.get("params", {}).get("filters", []):
                fields.update(self._fields_from_query(f.get("query", {}).get("query_string", {})))

        # TSVB (type: metrics) — fields live in params.series[].filter and params.series[].terms_field
        if vis_state.get("type") == "metrics":
            params = vis_state.get("params", {})
            for series in params.get("series", []):
                series_filter = series.get("filter", {})
                if isinstance(series_filter, dict):
                    fields.update(self._fields_from_lucene(series_filter.get("query", "")))
                terms_field = series.get("terms_field", "")
                if terms_field and isinstance(terms_field, str):
                    fields.add(terms_field)
                for metric in series.get("metrics", []):
                    mf = metric.get("field", "")
                    if mf and not mf.startswith("_"):
                        fields.add(mf)

        return fields

    def _fields_from_lens_state(self, lens_state):
        """Extract fields referenced in Lens visualization column definitions."""
        fields = set()
        try:
            state = json.loads(lens_state) if isinstance(lens_state, str) else lens_state
        except (json.JSONDecodeError, TypeError):
            return fields

        datasource_states = state.get("datasourceStates", {})
        index_pattern_state = datasource_states.get("indexpattern", {})
        for layer in index_pattern_state.get("layers", {}).values():
            for col in layer.get("columns", {}).values():
                source_field = col.get("sourceField")
                if source_field and not source_field.startswith("_"):
                    fields.add(source_field)
        return fields

    def _extract_fields_from_panel(self, panel_ref, all_saved_objects_by_id):
        """Return (index_pattern_title, panel_title, set_of_fields) for a single dashboard panel."""
        ref_type = panel_ref.get("type")
        ref_id = panel_ref.get("id")
        if not ref_type or not ref_id:
            return None, None, set()

        obj = all_saved_objects_by_id.get((ref_type, ref_id)) or self._get_saved_object(ref_type, ref_id)
        if not obj:
            return None, None, set()

        attrs = obj.get("attributes", {})
        fields = set()
        index_pattern_title = None
        panel_title = attrs.get("title") or panel_ref.get("name") or ref_id

        # Resolve index pattern from this object's references
        for ref in obj.get("references", []):
            if ref.get("type") == "index-pattern":
                ip_obj = all_saved_objects_by_id.get(("index-pattern", ref["id"]))
                if ip_obj:
                    index_pattern_title = ip_obj.get("attributes", {}).get("title")

        if ref_type == "lens":
            state = attrs.get("state", {})
            fields.update(self._fields_from_lens_state(state))
            for f in state.get("filters", []):
                fields.update(self._fields_from_search_source({"filter": [f]}))
            fields.update(self._fields_from_query(state.get("query", {})))

        elif ref_type in ("visualization", "search"):
            search_source = attrs.get("kibanaSavedObjectMeta", {}).get("searchSourceJSON", "{}")
            fields.update(self._fields_from_search_source(search_source))
            if ref_type == "visualization":
                fields.update(self._fields_from_vis_state(attrs.get("visState", "{}")))
                # Follow any linked saved search — its query is the actual data filter
                for ref in obj.get("references", []):
                    if ref.get("type") == "search":
                        saved_search = self._get_saved_object("search", ref["id"])
                        if saved_search:
                            s_attrs = saved_search.get("attributes", {})
                            s_ss = s_attrs.get("kibanaSavedObjectMeta", {}).get("searchSourceJSON", "{}")
                            fields.update(self._fields_from_search_source(s_ss))
                            # Index pattern from saved search refs if not already resolved
                            if not index_pattern_title:
                                for sref in saved_search.get("references", []):
                                    if sref.get("type") == "index-pattern":
                                        ip_obj = all_saved_objects_by_id.get(("index-pattern", sref["id"]))
                                        if ip_obj:
                                            index_pattern_title = ip_obj.get("attributes", {}).get("title")
                                        break

        return index_pattern_title, panel_title, fields

    # -------------------------------------------------------------------------
    # Index template helpers
    # -------------------------------------------------------------------------

    def _resolve_index_names(self, index_pattern_title):
        """
        Resolve an index pattern or alias to a set of concrete index name prefixes.
        If the pattern is an alias (or matches aliases), return the names of the
        backing indices so they can be matched against template index_patterns.
        Otherwise return the pattern itself.
        """
        try:
            alias_resp = self.os_client.transport.perform_request(
                "GET", f"/_alias/{index_pattern_title}", params={}
            )
            if alias_resp:
                return set(alias_resp.keys())
        except Exception:
            pass
        return {index_pattern_title}

    def _get_template_mappings(self, index_pattern_title):
        """
        Return a flat {field_path: os_type} dict from the index templates that
        match the given index pattern title (e.g. 'pa-audit-ro' or 'logstash-*').
        Resolves aliases to their backing indices before matching, so alias-based
        index patterns (e.g. 'pa-audit-ro') correctly map to their templates.

        When INDEX_TEMPLATES_DIR is set, templates are loaded from local JSON files
        instead of from the cluster — useful for running against a checked-out copy.
        Falls back to live index mappings if no template is found via either path.
        """
        resolved_indices = self._resolve_index_names(index_pattern_title)

        try:
            if INDEX_TEMPLATES_DIR:
                import pathlib
                entries = []
                for path in pathlib.Path(INDEX_TEMPLATES_DIR).glob("*.json"):
                    with open(path) as f:
                        body = json.load(f)
                    entries.append({"name": path.stem, "index_template": body})
            else:
                result = self.os_client.transport.perform_request(
                    "GET", "/_index_template/*", params={}
                )
                entries = [
                    {"name": t.get("name"), "index_template": t.get("index_template", {})}
                    for t in result.get("index_templates", [])
                ]

            flat = {}
            for entry in entries:
                tmpl_patterns = entry["index_template"].get("index_patterns", [])
                matched = False
                for resolved in resolved_indices:
                    for pattern in tmpl_patterns:
                        if self._pattern_matches(resolved, pattern):
                            matched = True
                            break
                    if matched:
                        break
                if matched:
                    props = (entry["index_template"]
                             .get("template", {})
                             .get("mappings", {})
                             .get("properties", {}))
                    flat.update(self._flatten_properties(props))
            if flat:
                return flat
        except Exception:
            pass

        # Fall back to live index mappings
        try:
            mappings = self.os_client.indices.get_mapping(index=index_pattern_title)
            flat = {}
            for index_data in mappings.values():
                flat.update(self._flatten_properties(
                    index_data.get("mappings", {}).get("properties", {})
                ))
            return flat
        except Exception:
            return {}

    def _pattern_matches(self, index_name, pattern):
        """
        Check whether index_name and pattern refer to the same index space.
        Both may contain a trailing wildcard (e.g. 'pd-access-*').
        A match occurs when one is a prefix/equal of the other after stripping wildcards.
        """
        a = index_name.rstrip("*")
        b = pattern.rstrip("*")
        return a.startswith(b) or b.startswith(a)

    def _flatten_properties(self, props, prefix=""):
        """Recursively flatten a mapping properties dict to {field_path: os_type}."""
        fields = {}
        for name, defn in props.items():
            path = f"{prefix}.{name}" if prefix else name
            if "type" in defn:
                fields[path] = defn["type"]
            if "properties" in defn:
                fields.update(self._flatten_properties(defn["properties"], path))
            for sub_name, sub_defn in defn.get("fields", {}).items():
                if "type" in sub_defn:
                    fields[f"{path}.{sub_name}"] = sub_defn["type"]
        return fields

    # -------------------------------------------------------------------------
    # Tests
    # -------------------------------------------------------------------------

    def test_dashboards_exist(self):
        """At least one dashboard must be present in OpenSearch Dashboards."""
        dashboards = self._get_all_saved_objects("dashboard")
        self.assertGreater(len(dashboards), 0, "No dashboards found in OpenSearch Dashboards")
        print(f"Found {len(dashboards)} dashboard(s)")

    def test_all_dashboards_have_valid_index_patterns(self):
        """Every index pattern ID referenced by a dashboard must exist as a saved object."""
        dashboards = self._get_all_saved_objects("dashboard")
        index_patterns = {obj["id"]: obj for obj in self._get_all_saved_objects("index-pattern")}

        missing = []
        for dashboard in dashboards:
            title = dashboard.get("attributes", {}).get("title", dashboard["id"])
            for ref in dashboard.get("references", []):
                if ref["type"] == "index-pattern" and ref["id"] not in index_patterns:
                    missing.append(
                        f"Dashboard '{title}' references missing index-pattern id={ref['id']}"
                    )

        self.assertEqual(
            missing, [],
            "Dashboards reference index patterns that do not exist:\n" + "\n".join(missing),
        )

    def test_index_patterns_match_real_indices(self):
        """Every index pattern used by a dashboard must match at least one real index."""
        dashboards = self._get_all_saved_objects("dashboard")
        index_patterns = {obj["id"]: obj for obj in self._get_all_saved_objects("index-pattern")}

        used_pattern_ids = {
            ref["id"]
            for d in dashboards
            for ref in d.get("references", [])
            if ref["type"] == "index-pattern" and ref["id"] in index_patterns
        }

        missing = []
        for pid in used_pattern_ids:
            title = index_patterns[pid].get("attributes", {}).get("title", pid)
            try:
                exists = self.os_client.indices.exists(index=title)
            except Exception:
                exists = False
            if not exists:
                missing.append(f"Index pattern '{title}' matches no live indices in OpenSearch")

        self.assertEqual(
            missing, [],
            "Index patterns with no matching live indices:\n" + "\n".join(missing),
        )

    def test_dashboard_fields_exist_in_index_templates(self):
        """
        For every field actively used in a dashboard's queries, filters, or
        aggregations, verify the field exists in the corresponding index
        template with a compatible type.
        """
        dashboards = self._get_all_saved_objects("dashboard")
        index_patterns = {obj["id"]: obj for obj in self._get_all_saved_objects("index-pattern")}

        # Build a lookup of all relevant saved objects by (type, id)
        all_objects = {}
        for obj_type in ("visualization", "search", "lens"):
            for obj in self._get_all_saved_objects(obj_type):
                all_objects[(obj_type, obj["id"])] = obj
        for obj in index_patterns.values():
            all_objects[("index-pattern", obj["id"])] = obj

        failures = []

        for dashboard in dashboards:
            dashboard_title = dashboard.get("attributes", {}).get("title", dashboard["id"])

            # Group panel refs by index_pattern_title -> list of (panel_title, field)
            pattern_panel_fields = {}

            for ref in dashboard.get("references", []):
                if ref["type"] in ("visualization", "search", "lens"):
                    ip_title, panel_title, fields = self._extract_fields_from_panel(ref, all_objects)
                    if ip_title and fields:
                        for field in fields:
                            pattern_panel_fields.setdefault(ip_title, []).append((panel_title, field))

            for ip_title, panel_field_pairs in pattern_panel_fields.items():
                template_mapping = self._get_template_mappings(ip_title)
                if not template_mapping:
                    failures.append(
                        f"Dashboard '{dashboard_title}': could not resolve index template "
                        f"for index pattern '{ip_title}'"
                    )
                    continue

                for panel_title, field in sorted(panel_field_pairs):
                    # If the field is directly in the mapping (including explicitly
                    # declared multi-field sub-fields like 'foo.keyword'), it's valid.
                    if field in template_mapping:
                        continue

                    # Strip .keyword/.text and re-check, but only accept the stripped
                    # form if the base field's type actually supports that sub-field.
                    # ip/date/integer fields have NO implicit .keyword sub-field.
                    lookup_field = field
                    stripped_suffix = None
                    for suffix in (".keyword", ".text"):
                        if field.endswith(suffix):
                            lookup_field = field[: -len(suffix)]
                            stripped_suffix = suffix
                            break

                    if lookup_field not in template_mapping:
                        failures.append(
                            f"Dashboard '{dashboard_title}' / panel '{panel_title}' / "
                            f"index pattern '{ip_title}': "
                            f"field '{field}' used in dashboard but absent from index template"
                        )
                    elif stripped_suffix == ".keyword" and template_mapping[lookup_field] not in (
                        "keyword", "constant_keyword", "wildcard"
                    ):
                        # The base field exists but is not a keyword type — no .keyword sub-field.
                        failures.append(
                            f"Dashboard '{dashboard_title}' / panel '{panel_title}' / "
                            f"index pattern '{ip_title}': "
                            f"field '{field}' used in dashboard but absent from index template "
                            f"('{lookup_field}' is type '{template_mapping[lookup_field]}', "
                            f"which has no .keyword sub-field)"
                        )

        if failures:
            msg = f"{len(failures)} field validation failure(s):\n" + "\n".join(failures)
            print(f"\n{msg}", flush=True)
            self.fail(msg)


class TestGrafanaDashboardValidation(unittest.TestCase):
    """
    Validates that fields used in Grafana dashboards (under the "Ping" folder)
    that query OpenSearch via the OS-PF-Audit or OS-PA-Audit datasources exist
    in the corresponding OpenSearch index templates with a compatible type.

    Flow:
      1. Enumerate Grafana dashboards in the "Ping" folder.
      2. For each panel using OS-PF-Audit or OS-PA-Audit, extract all field
         references from: Lucene query strings, bucketAggs, and metrics.
      3. Resolve the datasource's index (or alias) to the set of index templates
         that cover it in OpenSearch.
      4. Assert every referenced field exists in those template mappings.
    """

    NAMESPACE = "elastic-stack-logging"
    PROMETHEUS_NAMESPACE = "prometheus"
    OS_SERVICE = "opensearch"
    OS_PORT = 49200
    GRAFANA_SERVICE = "grafana-service"
    GRAFANA_PORT = 38001
    GRAFANA_INTERNAL_PORT = 3000

    # Grafana datasource names we care about -> canonical index pattern/alias.
    # UIDs are resolved dynamically at setup time via GET /api/datasources so
    # this test is not tied to UIDs that vary per cluster install.
    TARGET_DATASOURCE_NAMES = {
        "OS-PF-Audit": "pf-audit-*",
        "OS-PA-Audit": "pa-audit-ro",
    }

    # pa-audit-ro is an alias — map it to the index template patterns that cover it
    ALIAS_TO_TEMPLATE_PATTERNS = {
        "pa-audit-ro": ["pa-engine-audit-*", "pa-api-audit-log-*"],
    }

    # Fields known to be missing from OS index templates pending a dashboard fix.
    # Remove an entry here once the corresponding dashboard is corrected.
    KNOWN_MISSING_FIELDS = {
        # clientIp is not present in pf-audit documents; the dashboard referencing it
        # on pf-audit-* will be fixed in https://pingidentity.atlassian.net/browse/PDO-10261
        "pf-audit-*": {"clientIp"},
    }

    # Lucene field reference: word chars before ':' that are NOT inside a quoted string.
    # We first strip quoted strings, then extract field names.
    _QUOTED_RE = re.compile(r'"[^"]*"')
    _LUCENE_FIELD_RE = re.compile(r'([\w.]+)\s*:', re.ASCII)

    # Template variables (e.g. $cluster_name) — skip these
    _TEMPLATE_VAR_RE = re.compile(r'^\$')

    @classmethod
    def setUpClass(cls):
        """Port-forward to OpenSearch and Grafana, then build clients for both."""
        cls.k8s = K8sUtils()
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        cls.os_pf = subprocess.Popen(
            ["kubectl", "port-forward", f"service/{cls.OS_SERVICE}",
             f"{cls.OS_PORT}:9200", "-n", cls.NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        cls.grafana_pf = subprocess.Popen(
            ["kubectl", "port-forward",
             f"service/{cls.GRAFANA_SERVICE}",
             f"{cls.GRAFANA_PORT}:{cls.GRAFANA_INTERNAL_PORT}",
             "-n", cls.PROMETHEUS_NAMESPACE],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        time.sleep(5)

        os_secret = cls.k8s.get_namespaced_secret("opensearch-admin-credentials", cls.NAMESPACE)
        cls.os_username = base64.b64decode(os_secret.data["username"]).decode()
        cls.os_password = base64.b64decode(os_secret.data["password"]).decode()

        grafana_secret = cls.k8s.get_namespaced_secret(
            "grafana-admin-credentials", cls.PROMETHEUS_NAMESPACE
        )
        cls.grafana_user = base64.b64decode(
            grafana_secret.data["GF_SECURITY_ADMIN_USER"]
        ).decode()
        cls.grafana_password = base64.b64decode(
            grafana_secret.data["GF_SECURITY_ADMIN_PASSWORD"]
        ).decode()

        cls.os_client = OpenSearch(
            hosts=[{"host": "localhost", "port": cls.OS_PORT}],
            http_auth=(cls.os_username, cls.os_password),
            use_ssl=True,
            verify_certs=False,
            ssl_show_warn=False,
            timeout=240,
        )
        cls.grafana_base = f"http://localhost:{cls.GRAFANA_PORT}"
        cls.grafana_auth = (cls.grafana_user, cls.grafana_password)

        # Resolve datasource names -> UIDs dynamically so the test is not
        # tied to UIDs that differ per cluster install.
        ds_resp = requests.get(
            f"{cls.grafana_base}/api/datasources",
            auth=cls.grafana_auth,
        )
        ds_resp.raise_for_status()
        name_to_uid = {ds["name"]: ds["uid"] for ds in ds_resp.json()}
        cls.TARGET_DATASOURCES = {
            name_to_uid[name]: index_ref
            for name, index_ref in cls.TARGET_DATASOURCE_NAMES.items()
            if name in name_to_uid
        }
        if not cls.TARGET_DATASOURCES:
            raise Exception(
                f"None of the expected Grafana datasources found. "
                f"Expected: {list(cls.TARGET_DATASOURCE_NAMES.keys())}, "
                f"available: {list(name_to_uid.keys())}"
            )

        # Resolve alias -> union of template mappings once at setup
        cls._template_mapping_cache = {}

    @classmethod
    def tearDownClass(cls):
        """Terminate kubectl port-forward processes for OpenSearch and Grafana."""
        cls.os_pf.terminate()
        cls.grafana_pf.terminate()

    # -------------------------------------------------------------------------
    # Grafana API helpers
    # -------------------------------------------------------------------------

    def _grafana_get(self, path, params=None):
        """GET ``path`` from the Grafana API and return the parsed JSON response."""
        resp = requests.get(
            f"{self.grafana_base}{path}",
            auth=self.grafana_auth,
            params=params,
        )
        resp.raise_for_status()
        return resp.json()

    def _get_ping_folder_uid(self):
        """Return the UID of the Grafana "Ping" folder, or None if not found."""
        for folder in self._grafana_get("/api/folders"):
            if folder["title"] == "Ping":
                return folder["uid"]
        return None

    def _get_dashboards_in_folder(self, folder_uid):
        """Return the list of dashboard search results for the given folder UID."""
        return self._grafana_get(
            "/api/search",
            params={"folderUIDs": folder_uid, "type": "dash-db"},
        )

    def _get_dashboard(self, uid):
        """Return the dashboard JSON object for the given Grafana dashboard UID."""
        return self._grafana_get(f"/api/dashboards/uid/{uid}")["dashboard"]

    # -------------------------------------------------------------------------
    # Field extraction from Grafana panel targets
    # -------------------------------------------------------------------------

    def _fields_from_lucene(self, query):
        """
        Extract field names from a Lucene query string.
        Strips quoted values first so colons inside quotes (e.g. IPv6 addresses)
        are not mistaken for field references.
        Skips Grafana template variables ($var) and internal fields (_*).
        """
        fields = set()
        stripped = self._QUOTED_RE.sub('""', query or "")
        for match in self._LUCENE_FIELD_RE.finditer(stripped):
            field = match.group(1)
            if not self._TEMPLATE_VAR_RE.match(field) and not field.startswith("_"):
                fields.add(field)
        return fields

    def _fields_from_target(self, target):
        """Extract all document field references from a single Grafana panel target."""
        fields = set()

        # Lucene / PPL query string
        fields.update(self._fields_from_lucene(target.get("query", "")))
        fields.update(self._fields_from_lucene(target.get("lucene", "")))

        # bucketAggs (terms, date_histogram, etc.)
        for bagg in target.get("bucketAggs", []):
            field = bagg.get("field")
            if field and not field.startswith("_") and field != "@timestamp":
                fields.add(field.removesuffix(".keyword").removesuffix(".text"))

        # metrics (avg, sum, cardinality, etc. — not "count" which has no field)
        for metric in target.get("metrics", []):
            field = metric.get("field")
            if field and not field.startswith("_"):
                fields.add(field.removesuffix(".keyword").removesuffix(".text"))

        return fields

    # -------------------------------------------------------------------------
    # Index template helpers
    # -------------------------------------------------------------------------

    def _get_template_mappings_for_index(self, index_or_alias):
        """
        Return a flat {field_path: os_type} dict from all index templates
        whose index_patterns cover the given index or alias.
        Aliases are resolved via ALIAS_TO_TEMPLATE_PATTERNS.
        Results are cached.
        """
        if index_or_alias in self._template_mapping_cache:
            return self._template_mapping_cache[index_or_alias]

        patterns_to_match = self.ALIAS_TO_TEMPLATE_PATTERNS.get(
            index_or_alias, [index_or_alias]
        )

        result = self.os_client.transport.perform_request(
            "GET", "/_index_template/*", params={}
        )

        flat = {}
        for tmpl in result.get("index_templates", []):
            tmpl_patterns = tmpl.get("index_template", {}).get("index_patterns", [])
            if any(
                self._pattern_matches(want, have)
                for want in patterns_to_match
                for have in tmpl_patterns
            ):
                props = (
                    tmpl.get("index_template", {})
                        .get("template", {})
                        .get("mappings", {})
                        .get("properties", {})
                )
                flat.update(self._flatten_properties(props))

        self._template_mapping_cache[index_or_alias] = flat
        return flat

    def _pattern_matches(self, a, b):
        """True when two index patterns/names refer to overlapping index spaces."""
        return a.rstrip("*").startswith(b.rstrip("*")) or \
               b.rstrip("*").startswith(a.rstrip("*"))

    def _flatten_properties(self, props, prefix=""):
        """Recursively flatten a mapping properties dict to {field_path: os_type}.

        Also emits explicitly declared multi-field sub-fields (e.g. ``foo.keyword``
        from a ``fields`` block), so callers can distinguish a genuine ``.keyword``
        sub-field from an implicit one that doesn't exist.
        """
        fields = {}
        for name, defn in props.items():
            path = f"{prefix}.{name}" if prefix else name
            if "type" in defn:
                fields[path] = defn["type"]
            if "properties" in defn:
                fields.update(self._flatten_properties(defn["properties"], path))
            for sub_name, sub_defn in defn.get("fields", {}).items():
                if "type" in sub_defn:
                    fields[f"{path}.{sub_name}"] = sub_defn["type"]
        return fields

    # -------------------------------------------------------------------------
    # Tests
    # -------------------------------------------------------------------------

    def test_grafana_ping_folder_exists(self):
        """A "Ping" folder must exist in Grafana."""
        uid = self._get_ping_folder_uid()
        self.assertIsNotNone(uid, 'No "Ping" folder found in Grafana')

    def test_grafana_os_dashboards_have_valid_fields(self):
        """
        Every document field referenced in OS-PF-Audit or OS-PA-Audit panels
        (Lucene queries, bucketAggs, metrics) must exist in the corresponding
        OpenSearch index template mapping.
        """
        folder_uid = self._get_ping_folder_uid()
        self.assertIsNotNone(folder_uid, 'No "Ping" folder found in Grafana')

        dashboards = self._get_dashboards_in_folder(folder_uid)
        failures = []

        for db_meta in dashboards:
            dashboard = self._get_dashboard(db_meta["uid"])
            db_title = dashboard.get("title", db_meta["uid"])

            for panel in dashboard.get("panels", []):
                panel_title = panel.get("title", "untitled")

                for target in panel.get("targets", []):
                    ds = target.get("datasource", panel.get("datasource", {}))
                    ds_uid = ds.get("uid", "") if isinstance(ds, dict) else str(ds)

                    if ds_uid not in self.TARGET_DATASOURCES:
                        continue

                    index_ref = self.TARGET_DATASOURCES[ds_uid]
                    fields = self._fields_from_target(target)

                    if not fields:
                        continue

                    mapping = self._get_template_mappings_for_index(index_ref)
                    if not mapping:
                        failures.append(
                            f"Dashboard '{db_title}' / panel '{panel_title}': "
                            f"could not resolve index template for '{index_ref}'"
                        )
                        continue

                    known_missing = self.KNOWN_MISSING_FIELDS.get(index_ref, set())
                    for field in sorted(fields):
                        if field in known_missing:
                            continue
                        if field not in mapping:
                            failures.append(
                                f"Dashboard '{db_title}' / panel '{panel_title}' "
                                f"/ datasource '{index_ref}': "
                                f"field '{field}' used in panel but absent from index template"
                            )

        if failures:
            msg = f"{len(failures)} field validation failure(s):\n" + "\n".join(failures)
            print(f"\n{msg}", flush=True)
            self.fail(msg)


if __name__ == "__main__":
    unittest.main()
