import os
import unittest
import uuid

import pingone_ui as p1_ui


@unittest.skipIf(
    os.environ.get("ENV_TYPE") == "customer-hub",
    "Customer-hub CDE detected, skipping test module",
)
class TestOpensearchGlobalTenantWrite(p1_ui.ConsoleUILoginTestBase):
    """Regression guard for OpenSearch Dashboards tenant permissions.

    Customers reach OSD via the os-configteam backend role (PingOne attribute
    p1asOpensearchRoles). customer_role grants that user kibana_all_read on the
    global tenant and kibana_all_write only on their own 'customer' tenant.
    These tests exercise the saved-objects API the same way the OSD UI does
    when a user saves/deletes a dashboard or index pattern, to verify the
    boundary: writes to the global tenant must be rejected, writes to the
    customer's own tenant must keep working.

    Regression context: PDO-12522 — the query_save_export role was mapped to
    the customer backend role and granted kibana_all_write on the global
    tenant, letting customers create and delete shared global-tenant
    dashboards. The role (eng-base) and its role mapping (eng-docker) were
    removed.
    """

    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()
        cls.public_hostname = os.getenv(
            "OPENSEARCH_PUBLIC_HOSTNAME",
            f"https://logs.{os.environ['TENANT_DOMAIN']}",
        )
        cls.console_url = f"{cls.public_hostname}/auth/openid/login"
        cls.config = p1_ui.PingOneUITestConfig(
            app_name="Opensearch",
            console_url=cls.console_url,
            roles={"p1asOpensearchRoles": ["os-configteam"]},
            access_granted_xpaths=["//div[contains(text(), 'Introducing new OpenSearch Dashboards look & feel')]"],
            access_denied_xpaths=["//h3[contains(text(), 'Missing Role')]"],
        )

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()

    def _fetch_in_session(self, method: str, path: str, tenant: str, body: dict = None) -> dict:
        """Log in via PingOne SSO, land on OSD, then issue a same-origin fetch
        from the authenticated browser session (session cookies carried
        automatically), mimicking the API call the OSD UI issues against the
        given tenant. Returns {'status': <int>, 'body': <str>}."""
        self.p1_ui.wait_until_url_is_reachable(self.config.console_url)
        self.p1_ui.login(
            url=p1_ui.ENV_UI_URL,
            username=self.config.local_user.username,
            password=self.config.local_user.password,
        )
        self.p1_ui.browser.get(self.config.console_url)
        # Wait for the OIDC round-trip to land back on the OSD origin before
        # running the same-origin fetch
        self.p1_ui.wait.until(lambda d: d.current_url.startswith(self.public_hostname))
        self.p1_ui.browser.set_script_timeout(30)
        script = """
          const [method, path, tenant, body, callback] = arguments;
          fetch(path, {
            method: method,
            headers: {
              'securitytenant': tenant,
              'osd-xsrf': 'true',
              'Content-Type': 'application/json',
            },
            body: body ? JSON.stringify(body) : undefined,
          })
            .then(r => r.text().then(t => callback({status: r.status, body: t})))
            .catch(e => callback({status: 0, body: String(e)}));
        """
        return self.p1_ui.browser.execute_async_script(script, method, path, tenant, body)

    def test_configteam_user_cannot_write_global_tenant(self):
        object_id = f"ci-osd-tenant-test-{uuid.uuid4().hex[:8]}"
        # POST /api/saved_objects/{type}/{id} is the create endpoint the OSD UI
        # uses when saving a new object (PUT is update-only)
        res = self._fetch_in_session(
            "POST",
            f"/api/saved_objects/index-pattern/{object_id}",
            "global_tenant",
            {"attributes": {"title": "ci-osd-tenant-test-*"}},
        )
        self.assertEqual(
            res["status"],
            403,
            f"os-configteam user must NOT be able to write the global tenant, "
            f"got status {res['status']}: {res['body']}",
        )

    def test_configteam_user_can_write_customer_tenant(self):
        object_id = f"ci-osd-tenant-test-{uuid.uuid4().hex[:8]}"
        # POST (create) rather than PUT (update): PUT on a nonexistent id
        # returns 404 Saved object not found regardless of permissions
        res = self._fetch_in_session(
            "POST",
            f"/api/saved_objects/index-pattern/{object_id}",
            "customer",
            {"attributes": {"title": "logstash-*"}},
        )
        self.assertEqual(
            res["status"],
            200,
            f"os-configteam user should still be able to write their own "
            f"'customer' tenant, got status {res['status']}: {res['body']}",
        )


if __name__ == "__main__":
    unittest.main()
