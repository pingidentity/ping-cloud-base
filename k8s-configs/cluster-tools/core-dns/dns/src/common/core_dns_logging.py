import inspect
import sys
import logging
import os
from tabulate import tabulate
from enum import Enum


class LogLevel(Enum):
    INFO = 1
    DEBUG = 2
    WARNING = 3
    ERROR = 4


class CoreDnsLogger:

    def __init__(self, verbose):
        logger = logging.getLogger()

        if verbose:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)

        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        self.logger = logger

    def log(self, message, log_level=LogLevel.INFO):
        func = inspect.currentframe().f_back.f_code
        if log_level == LogLevel.DEBUG:
            self.logger.debug("%s - %s" % (func.co_name, message))
        elif log_level == LogLevel.WARNING:
            self.logger.warning("%s - %s" % (
                func.co_name,
                message
            ))
        elif log_level == LogLevel.ERROR:
            self.logger.error("%s - %s" % (
                func.co_name,
                message
            ))
        else:
            self.logger.info("%s - %s" % (
                func.co_name,
                message
            ))

    def log_env_vars(self):
        self.log("Environment variables:", LogLevel.DEBUG)
        self.log(tabulate(sorted(os.environ.items()), headers=["Name", "Value"]), LogLevel.DEBUG)

        # separate output
        # with space
        print()
