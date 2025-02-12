import requests
import requests.auth


def get_token(app_id: str, app_secret: str, app_token_url: str, scopes: str) -> str:
    """
    Get OAuth token for a PingOne app using client credentials flow
    :param app_id: PingOne app ID
    :param app_secret: PingOne app secret
    :param app_token_url: PingOne app token URL
    :param scopes: PingOne app scopes, e.g. "p1asPAOperatorRoles" or "p1asPFOperatorRoles"
    :return: Access token
    """
    res = requests.post(
        url=app_token_url,
        data={
            "grant_type": "client_credentials",
            "scopes": scopes,
        },
        auth=requests.auth.HTTPBasicAuth(app_id, app_secret),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    res.raise_for_status()

    token = res.json()["access_token"]
    return token
