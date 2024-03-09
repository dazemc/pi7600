"""
This provides Settings for all modules
"""
import serial
import sys
from Globals import *


# import RPi.GPIO as GPIO


def py_version_check() -> bool:
    """
    Python minimum version check (3.10)
    :return: bool
    """
    try:
        if float(sys.version[:sys.version[2:].find('.') + 2]) < 3.10:
            print("Python version must be 3.10 or greater, buildpy.sh will build latest stable release from source. "
                  "Alternatively, you can use the included venv with ./venv/Scripts/activate")
            print("\nExiting...")
            return False
    except:
        user_input = input("Python version check failed. Depends on 3.10 or greater, continue anyways(y/N?").lower()
        if user_input in ["", "n"]:
            print("\nExiting...")
            return False
    return True


class Settings:
    def __init__(self, com: str, baudrate: int) -> None:
        """
        Initializes Settings class
        :param port: str
        :param baudrate: int
        """
        self.com = com
        self.baudrate = baudrate
        self.ser = serial.Serial(self.com, self.baudrate)
        self.ser.flushInput()
        self.first_run = True
        if self.first_run:
            self.perform_initial_checks()

    def perform_initial_checks(self) -> None:
        """
        Initial environment checks
        :param self:
        :return: None
        """
        pyversion = py_version_check()
        if pyversion:
            self.first_run = False
        else:
            sys.exit(EXIT_FAILURE_CODE)
