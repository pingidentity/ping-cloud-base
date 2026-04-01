import os
import time
import unittest
import warnings
import zipfile
from pathlib import Path

import boto3
import pingone_ui as p1_ui
import urllib3
import yaml
from selenium.common.exceptions import NoSuchElementException, TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

import aws_utils
import k8s_utils


NAMESPACE = os.getenv("NAMESPACE", "ping-cloud")

# Admin ConfigMap values
AWS = aws_utils.AWSUtils()
K8S = k8s_utils.K8sUtils()
PF_ADMIN_ENV_VARS = K8S.get_configmap_values(configmap_name="pingfederate-admin-environment-variables", namespace=NAMESPACE)
CONFIG_DATA_BUCKET_URI = AWS.get_parameter(name=PF_ADMIN_ENV_VARS.get("CONFIG_DATA_BUCKET_URI"))
CONFIG_DATA_S3_SYNC_INTERVAL_SECONDS = int(PF_ADMIN_ENV_VARS.get("CONFIG_DATA_S3_SYNC_INTERVAL_SECONDS", "30"))

# Paths inside the PF container — templates
TEMPLATE_DIR = "/opt/out/instance/server/default/conf/template"
TEMPLATE_DEFAULTS_DIR = "/opt/server/server/default/conf/template"
TEMPLATE_S3_STAGING_DIR = "/opt/out/instance/server/default/tmp/template"
TEMPLATE_S3_PREFIX = f"{CONFIG_DATA_BUCKET_URI}/pingfederate/templates/"


class PFSyncTestHelper:
	"""Reusable helper for S3 sync integration tests.

	Each instance is bound to a specific target directory, defaults directory,
	config-file path (inside the pod), and staging dir backup path.
	"""

	def __init__(
		self,
		k8s: k8s_utils.K8sUtils,
		target_dir: str,
		defaults_dir: str,
		staging_dir: str,
		s3_prefix: str,
		sync_interval: int,
	):
		self.k8s = k8s
		self.target_dir = target_dir
		self.defaults_dir = defaults_dir
		self.staging_dir = staging_dir
		self.s3_prefix = s3_prefix
		self.sync_interval = sync_interval

		self.namespace = NAMESPACE
		self.pf_admin_pod = "pingfederate-admin-0"
		self.pf_admin_container = "pingfederate-admin"
		self.pf_engine_pod = "pingfederate-0"
		self.pf_engine_container = "pingfederate"

	# -- kubectl exec ---------------------------------------------------------

	def pod_exec(self, pod_name: str, container_name: str, command: str) -> str:
		return self.k8s.exec_command(
			namespace=self.namespace,
			pod_name=pod_name,
			command=["sh", "-c", command],
			container_name=container_name,
		)

	def pod_exec_exit_code(self, pod_name: str, container_name: str, command: str) -> int:
		result = self.pod_exec(pod_name, container_name, f"{command} && echo __OK__ || echo __FAIL__")
		return 0 if "__OK__" in result else 1

	def admin_exec(self, command: str) -> str:
		return self.pod_exec(
			pod_name=self.pf_admin_pod,
			container_name=self.pf_admin_container,
			command=command,
		)

	def admin_exec_exit_code(self, command: str) -> int:
		return self.pod_exec_exit_code(
			pod_name=self.pf_admin_pod,
			container_name=self.pf_admin_container,
			command=command,
		)

	def engine_exec(self, command: str) -> str:
		"""Run `command` in the engine pod (first engine pod/instance)."""
		return self.pod_exec(
			pod_name=self.pf_engine_pod,
			container_name=self.pf_engine_container,
			command=command,
		)

	def engine_exec_exit_code(self, command: str) -> int:
		return self.pod_exec_exit_code(
			pod_name=self.pf_engine_pod,
			container_name=self.pf_engine_container,
			command=command,
		)

	# -- pod file helpers -----------------------------------------------------

	def file_exists_in_admin_pod(self, filename: str) -> bool:
		return self.admin_exec_exit_code(f"test -f {self.target_dir}/{filename}") == 0

	def list_files_in_admin_pod(self) -> list[str]:
		output = self.admin_exec(f"find {self.target_dir} -type f -printf '%P\\n' 2>/dev/null").strip()
		return [f for f in output.splitlines() if f] if output else []

	def list_default_files_in_admin_pod(self) -> list[str]:
		output = self.admin_exec(f"find {self.defaults_dir} -type f -printf '%P\\n' 2>/dev/null").strip()
		return [f for f in output.splitlines() if f] if output else []

	def file_exists_in_engine_pod(self, filename: str) -> bool:
		return self.engine_exec_exit_code(f"test -f {self.target_dir}/{filename}") == 0

	def list_files_in_engine_pod(self) -> list[str]:
		output = self.engine_exec(f"find {self.target_dir} -type f -printf '%P\\n' 2>/dev/null").strip()
		return [f for f in output.splitlines() if f] if output else []

	def list_default_files_in_engine_pod(self) -> list[str]:
		output = self.engine_exec(f"find {self.defaults_dir} -type f -printf '%P\\n' 2>/dev/null").strip()
		return [f for f in output.splitlines() if f] if output else []

	# -- wait for sync --------------------------------------------------------

	def wait_for_sync(self, cycles: int = 2) -> None:
		wait_time = self.sync_interval * cycles + 10
		time.sleep(wait_time)


@unittest.skipIf(
	os.environ.get("ENV_TYPE") == "customer-hub",
	"Customer-hub CDE detected, skipping test module",
)
class TestPfTemplatesUI(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.tenant_domain = os.getenv("TENANT_DOMAIN")
		cls.self_service_url = f"https://self-service.{cls.tenant_domain}"
		cls.region = os.getenv("REGION", "us-west-2")
		cls.config_data_bucket = CONFIG_DATA_BUCKET_URI.replace("s3://", "").strip("/")

		resources_dir = Path(__file__).parent / "resources"
		cls.templates_zip_path = resources_dir / "templates.zip"
		cls.zip_slip_path = resources_dir / "slip.zip"

		cls.config_type_keys = ["templates", "language-packs"]

		cls.config = p1_ui.PingOneUITestConfig(
			app_name="SelfServiceUI",
			console_url=cls.self_service_url,
			roles={"p1asSelfServiceRoles": ["all-ss-admin"]},
			access_granted_xpaths=[],
			access_denied_xpaths=[],
			create_local_only=True,
		)

		cls.ui_driver = p1_ui.PingOneUIDriver()
		cls.ui_driver.setup_browser(window_size="1920,1080")
		cls.ui_driver.login(
			url=cls.config.console_url,
			username=cls.config.local_user.username,
			password=cls.config.local_user.password,
		)
		cls.browser = cls.ui_driver.browser

		warnings.filterwarnings(
			"ignore", category=urllib3.exceptions.InsecureRequestWarning
		)

		cls.wait_time_sec = 10
		cls.wait = WebDriverWait(cls.browser, 30)
		cls.loader_locator = (
			By.CSS_SELECTOR,
			'div[aria-label="Loading in progress"]',
		)

		cls.s3 = boto3.client("s3", region_name=cls.region)

		cls.k8s = k8s_utils.K8sUtils()
		cls.pf = PFSyncTestHelper(
			k8s=cls.k8s,
			target_dir=TEMPLATE_DIR,
			defaults_dir=TEMPLATE_DEFAULTS_DIR,
			staging_dir=TEMPLATE_S3_STAGING_DIR,
			s3_prefix=TEMPLATE_S3_PREFIX,
			sync_interval=CONFIG_DATA_S3_SYNC_INTERVAL_SECONDS,
		)

	@classmethod
	def tearDownClass(cls) -> None:
		cls.browser.quit()

	def wait_for_loader(self):
		try:
			WebDriverWait(self.browser, self.wait_time_sec).until(
				EC.presence_of_element_located(self.loader_locator)
			)
		except TimeoutException:
			pass

		try:
			WebDriverWait(self.browser, self.wait_time_sec).until_not(
				EC.presence_of_element_located(self.loader_locator)
			)
		except TimeoutException:
			pass

	def select_test_environment(self):
		env_selector_btn = self.wait.until(
			EC.element_to_be_clickable((By.CSS_SELECTOR, '[data-testid="env-selector"]'))
		)
		env_selector_btn.click()
		self.wait.until(
			EC.presence_of_element_located(
				(By.XPATH, '//ul[@aria-label="Environment Selector" and @role="menu"]')
			)
		)
		menu_item = self.wait.until(
			EC.element_to_be_clickable((By.XPATH, '//li[@role="menuitem"]'))
		)
		menu_item.click()
		self.wait.until(
			EC.invisibility_of_element_located(
				(By.XPATH, '//ul[@aria-label="Environment Selector" and @role="menu"]')
			)
		)

	def navigate_to_page(self, path: str):
		print(f"Navigating to {path} page")
		nav_id = f"/self-service/configurations/{path}"
		nav_xpath = f'//*[@id="{nav_id}"]'

		# Expand Product Configuration section only when the nested nav item is not visible.
		nav_candidates = self.browser.find_elements(By.XPATH, nav_xpath)
		nav_is_visible = any(candidate.is_displayed() for candidate in nav_candidates)

		if not nav_is_visible:
			product_configuration_section = self.wait.until(
				EC.element_to_be_clickable(
					(By.CSS_SELECTOR, 'div[data-testid="Product Configuration"]')
				)
			)
			product_configuration_section.click()
			self.wait_for_loader()

		nav_btn = self.wait.until(
			EC.element_to_be_clickable((By.XPATH, nav_xpath))
		)
		classes = nav_btn.get_attribute("class") or ""
		if "is-selected" not in classes.split():
			nav_btn.click()
			self.wait_for_loader()

	def get_config_display_name(self, config_key: str) -> str:
		return {
			"templates": "Templates",
			"language-packs": "Language Packs",
		}.get(config_key, config_key)

	def list_container(self):
		return self.wait.until(
			EC.visibility_of_element_located(
				(By.CSS_SELECTOR, 'div[data-testid="PingFederate Configuration"]')
			)
		)

	def get_row(self, config_key: str):
		container = self.list_container()
		# Prefer backend key lookup; fall back to visible display name for UI compatibility.
		rows = container.find_elements(
			By.CSS_SELECTOR,
			f'div[role="row"][data-key="{config_key}"]',
		)
		if rows:
			return rows[0]

		display_name = self.get_config_display_name(config_key)
		return container.find_element(
			By.XPATH,
			f'.//div[@role="row"][.//*[normalize-space()="{display_name}"]]',
		)

	def has_configure_button(self, config_key: str) -> bool:
		row = self.get_row(config_key)
		return (
			len(
				row.find_elements(
					By.XPATH,
					'.//button[normalize-space()="Configure"]',
				)
			)
			> 0
		)

	def assert_all_unconfigured(self):
		for config_key in self.config_type_keys:
			with self.subTest(msg=f"{config_key} should be unconfigured"):
				self.assertTrue(
					self.has_configure_button(config_key),
					f"Expected Configure button for '{config_key}'",
				)

	def click_configure_for(self, config_key: str):
		row = self.get_row(config_key)
		configure_btn = row.find_element(
			By.XPATH,
			'.//button[normalize-space()="Configure"]',
		)
		configure_btn.click()

	def upload_zip_from_modal(self, zip_path: Path):
		self.wait.until(
			EC.visibility_of_element_located(
				(By.XPATH, '//div[@role="dialog"]//*[text()="Upload File"]')
			)
		)

		file_input = self.wait.until(
			EC.presence_of_element_located(
				(By.CSS_SELECTOR, 'div[role="dialog"] input[type="file"]')
			)
		)
		file_input.send_keys(str(zip_path))

		save_btn = self.wait.until(
			EC.element_to_be_clickable(
				(By.XPATH, '//div[@role="dialog"]//button[normalize-space()="Save"]')
			)
		)
		save_btn.click()

	def get_toast_notification(self):
		toast = self.wait.until(
			EC.visibility_of_element_located(
				(By.XPATH, "//div[@role='status' and @aria-label]")
			)
		)
		toast_type = toast.get_attribute("aria-label")
		try:
			message_element = toast.find_element(By.TAG_NAME, "span")
			toast_text = message_element.text.strip()
		except Exception:
			toast_text = toast.text.strip()
		return toast_type, toast_text

	def get_row_badge_text(self, config_key: str):
		row = self.get_row(config_key)
		badges = row.find_elements(By.XPATH, './/span[contains(@class, "badge")]')
		if badges:
			for badge in badges:
				text = badge.text.strip()
				if text:
					return text

		known_badges = ["Upload Error", "Error", "Complete", "Updating", "Creating"]
		for label in known_badges:
			if row.find_elements(By.XPATH, f'.//*[normalize-space()="{label}"]'):
				return label
		return None

	def wait_for_status(self, config_key: str, expected_status: str, interval_sec: int = 10, tries: int = 3):
		# Poll status across page refreshes using fixed retries.
		last_seen = None
		for _ in range(tries):
			try:
				badge = self.get_row_badge_text(config_key)
				if badge:
					last_seen = badge
				if badge == expected_status:
					return badge
			except NoSuchElementException:
				pass

			time.sleep(interval_sec)
			self.browser.refresh()
			self.wait_for_loader()
			self.list_container()

		self.fail(
			f"Timed out waiting for {config_key} status '{expected_status}'. "
			f"Last seen: {last_seen}"
		)

	def reset_to_default(self, config_key: str):
		# Open row action menu and execute reset flow via confirmation modal.
		row = self.get_row(config_key)

		more_options_btn = row.find_element(
			By.CSS_SELECTOR,
			'button[aria-label="more options"]',
		)
		more_options_btn.click()

		reset_option = self.wait.until(
			EC.element_to_be_clickable((By.XPATH, "//li[@data-key='delete']"))
		)
		reset_option.click()

		modal = self.wait.until(
			EC.visibility_of_element_located((By.CSS_SELECTOR, 'div[role="dialog"]'))
		)
		modal_locator = (By.CSS_SELECTOR, 'div[role="dialog"]')

		checkbox_label = WebDriverWait(modal, self.wait_time_sec).until(
			EC.element_to_be_clickable((By.XPATH, "//label[@for='confirm-reset']"))
		)
		checkbox_label.click()

		reset_btn = WebDriverWait(modal, self.wait_time_sec).until(
			EC.element_to_be_clickable(
				(By.XPATH, '//div[@role="dialog"]//button[normalize-space()="Reset"]')
			)
		)
		reset_btn.click()

		self.wait.until(EC.invisibility_of_element_located(modal_locator))

	def ensure_config_unconfigured(self, config_key: str):
		self.browser.refresh()
		self.wait_for_loader()
		self.list_container()
		if not self.has_configure_button(config_key):
			self.reset_to_default(config_key)
			_, msg = self.get_toast_notification()
			self.assertIn("reset to default", msg.lower())
			self.browser.refresh()
			self.wait_for_loader()
			self.assertTrue(self.has_configure_button(config_key))

	def get_expected_template_object_keys(self, zip_path: Path) -> set[str]:
		keys = set()
		with zipfile.ZipFile(zip_path, "r") as zf:
			for info in zf.infolist():
				if info.is_dir() or "MACOSX" in info.filename:
					continue
				clean_name = info.filename.lstrip("/")
				keys.add(clean_name)
		return keys

	def get_s3_keys_under_prefix(self, bucket: str, prefix: str) -> set[str]:
		keys = set()
		paginator = self.s3.get_paginator("list_objects_v2")
		for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
			for content in page.get("Contents", []):
				keys.add(content["Key"])
		return keys

	def open_view_panel(self, config_key: str):
		row = self.get_row(config_key)
		row.click()
		self.wait.until(
			EC.visibility_of_element_located((By.CSS_SELECTOR, 'div[data-testid="view"]'))
		)

	def get_upload_errors_from_view(self) -> list[str]:
		panel = self.wait.until(
			EC.visibility_of_element_located((By.CSS_SELECTOR, 'div[data-testid="view"]'))
		)
		items = panel.find_elements(By.XPATH, ".//li")
		errors = []
		for item in items:
			text = item.text.strip()
			if text:
				errors.append(text)
		return errors

	def setUp(self) -> None:
		self.select_test_environment()
		self.navigate_to_page("pingfederate")

	def test_01_templates_upload_in_ui(self):
		"""Valid templates should successfully upload into self-service UI."""
		self.assertTrue(
			self.templates_zip_path.exists(),
			f"Templates zip file not found: {self.templates_zip_path}",
		)
		self.assertTrue(
			self.config_data_bucket,
			"Missing CONFIG_DATA_S3_BUCKET_URI (or SS_CONFIG_DATA_BUCKET_URI)",
		)

		# Ensure both configurable items start from unconfigured state.
		for config_key in self.config_type_keys:
			self.ensure_config_unconfigured(config_key)
		self.assert_all_unconfigured()

		# Upload the valid templates zip.
		self.click_configure_for("templates")
		self.upload_zip_from_modal(self.templates_zip_path)

		toast_type, message = self.get_toast_notification()
		self.assertEqual(toast_type, "Success Message")
		self.assertIn("Templates", message)
		self.assertTrue(
			"configured" in message.lower() or "updated" in message.lower(),
			f"Unexpected upload success message: {message}",
		)
		print(f"Upload success: {message}")

	def test_02_templates_upload_in_s3(self):
		"""Valid templates upload should result in expected S3 objects and status updates."""
		# Wait for the "Creating" state before final completion validation.
		WebDriverWait(self.browser, 30).until(
			lambda _: self.get_row_badge_text("templates") == "Creating"
		)
		print("Observed status after upload: Creating")

		time.sleep(10)
		self.browser.refresh()
		self.wait_for_loader()
		
		# Wait for the status to turn "Complete"
		badge = self.get_row_badge_text("templates")
		if badge != "Complete":
			badge = self.wait_for_status(
				config_key="templates",
				expected_status="Complete",
				interval_sec=10,
				tries=3,
			)
		self.assertEqual(badge, "Complete")
		print("Status changed to Complete")

		# Verify uploaded objects and deployed bundle were written to config-data bucket.
		expected_keys = self.get_expected_template_object_keys(self.templates_zip_path)
		expected_keys = set([f"pingfederate/templates/{key}" for key in expected_keys])
		actual_keys = self.get_s3_keys_under_prefix(
			bucket=self.config_data_bucket,
			prefix="pingfederate/templates/",
		)
		missing = expected_keys.difference(actual_keys)
		self.assertFalse(missing, f"Missing uploaded files in S3: {sorted(missing)}")
		print("Verified uploaded template files in S3")

		deployed_key = "pingfederate/deployed/templates.zip"
		deployed_obj = self.s3.list_objects_v2(
			Bucket=self.config_data_bucket,
			Prefix=deployed_key,
			MaxKeys=1,
		)
		self.assertTrue(
			any(content.get("Key") == deployed_key for content in deployed_obj.get("Contents", [])),
			f"Expected deployed zip not found: {deployed_key}",
		)
		print("Verified deployed templates.zip in S3")

	def test_03_templates_synced_in_pf_admin(self):
		"""Valid templates s3 upload should result in successful sync in PingFederate admin pod."""
		expected_keys = self.get_expected_template_object_keys(self.templates_zip_path)
		self.pf.wait_for_sync()

		missing_keys = []
		for key in expected_keys:
			if not self.pf.file_exists_in_admin_pod(key):
				missing_keys.append(key)

		self.assertEqual(
			missing_keys,
			[],
			f"Files from S3 not found in {self.pf.pf_admin_pod} pod {self.pf.target_dir}: {missing_keys}"
		)

	def test_04_templates_synced_in_pf_engine(self):
		"""Valid templates s3 upload should result in successful sync in PingFederate engine pod."""
		expected_keys = self.get_expected_template_object_keys(self.templates_zip_path)
		self.pf.wait_for_sync()

		missing_keys = []
		for key in expected_keys:
			if not self.pf.file_exists_in_engine_pod(key):
				missing_keys.append(key)

		self.assertEqual(
			missing_keys,
			[],
			f"Files from S3 not found in {self.pf.pf_engine_pod} pod {self.pf.target_dir}: {missing_keys}"
		)

	def test_05_templates_upload_reset_to_default(self):
		"""Templates should reset to default when deleted in UI."""
		# Reset templates back to default.
		self.reset_to_default("templates")
		_, reset_message = self.get_toast_notification()
		self.assertIn("reset to default", reset_message.lower())
		print(f"Reset completed: {reset_message}")

		self.browser.refresh()
		self.wait_for_loader()
		self.assertTrue(
			self.has_configure_button("templates"),
			"Configure button did not re-appear after reset",
		)

	def test_06_templates_reset_to_default_in_pf_admin(self):
		"""PingFederate admin templates should reset to defaults after Self-Service reset."""
		self.pf.wait_for_sync()

		default_files = set(self.pf.list_default_files_in_admin_pod())
		current_files = set(self.pf.list_files_in_admin_pod())
		extra_files = current_files.difference(default_files)
		self.assertFalse(
			extra_files,
			f"Expected no extra files in {self.pf.pf_admin_pod} pod after reset, but found: {sorted(extra_files)}",
		)

	def test_07_templates_reset_to_default_in_pf_engine(self):
		"""PingFederate engine templates should reset to defaults after Self-Service reset."""
		self.pf.wait_for_sync()

		default_files = set(self.pf.list_default_files_in_engine_pod())
		current_files = set(self.pf.list_files_in_engine_pod())
		extra_files = current_files.difference(default_files)
		self.assertFalse(
			extra_files,
			f"Expected no extra files in {self.pf.pf_engine_pod} pod after reset, but found: {sorted(extra_files)}",
		)

	def test_08_templates_zip_slip_shows_error_details(self):
		"""Upload malicious zip and confirm validation errors are surfaced."""
		self.assertTrue(
			self.zip_slip_path.exists(),
			f"Zip-slip test file not found: {self.zip_slip_path}",
		)

		self.ensure_config_unconfigured("templates")

		# Upload invalid archive.
		self.click_configure_for("templates")
		self.upload_zip_from_modal(self.zip_slip_path)

		toast_type, message = self.get_toast_notification()
		self.assertEqual(toast_type, "Success Message")
		self.assertIn("Templates", message)
		print(f"Zip-slip upload success: {message}")

		badge = self.wait_for_status(
			config_key="templates",
			expected_status="Upload Error",
			interval_sec=10,
			tries=3,
		)
		self.assertEqual(badge, "Upload Error")
		print(f"Observed expected error status: {badge}")

		# Validate detailed errors in the side panel.
		self.open_view_panel("templates")
		errors = self.get_upload_errors_from_view()
		self.assertTrue(errors, "Expected upload errors in view panel but found none")
		print(f"Captured upload errors: {errors}")

		joined_errors = " ".join(errors).lower()
		self.assertTrue(
			any(keyword in joined_errors for keyword in ["unsafe path", "error", "..", "zip"]),
			f"Unexpected upload error text: {errors}",
		)

		self.browser.refresh()
		self.wait_for_loader()
		self.list_container()

		# Reset templates back to default.
		self.reset_to_default("templates")
		_, reset_message = self.get_toast_notification()
		self.assertIn("reset to default", reset_message.lower())
		print(f"Reset completed: {reset_message}")

		self.browser.refresh()
		self.wait_for_loader()
		self.assertTrue(self.has_configure_button("templates"))
