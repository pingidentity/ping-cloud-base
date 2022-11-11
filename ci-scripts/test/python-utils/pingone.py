import os

v2_admin_environment_id = os.getenv("ADMIN_ENV_ID", "unset")
admin_env_ui_url = (
    f"https://console-staging.pingone.com/?env={v2_admin_environment_id}#home?nav=home"
)
