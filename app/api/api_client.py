from app.api.base_requests import BaseRequest
from app.api.urls import Urls


class ApiClient(BaseRequest):
    def __init__(self) -> None:
        self.token = None

    def login(self):
        """Method to execute login"""
        r = self.get(Urls.LOGIN)
        self.token = r.json().get('token')

    def get_folders(self):
        r = self.get(Urls.FOLDERS)
        r.raise_for_status()
