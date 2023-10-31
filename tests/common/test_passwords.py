from check_passwords import CheckPasswords
import unittest

namespace = "ping-cloud"


class TestPasswords(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.test_utils = CheckPasswords()

    def test_check_passwords(self):
        self.assertTrue(self.test_utils.check_passwords(namespace), "Found secrets in the logs")