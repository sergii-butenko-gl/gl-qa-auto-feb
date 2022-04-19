from app.api.api_client import ApiClient


def test_login_succesfull():
    assert ApiClient.login() is not None
