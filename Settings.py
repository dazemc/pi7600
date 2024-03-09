import serial
import sys


# import RPi.GPIO as GPIO


class Settings:
    def __init__(self) -> None:
        self.ser = serial.Serial("/dev/ttyUSB2", 115200)  # pi zero w should always be USB2@115200
        self.ser.flushInput()
        self.first_run = True
        if self.first_run:
            first_run(self)


def first_run(self) -> None:
    """
    Initial environment checks
    :param self:
    :return: None
    """
    pyversion = py_version_check()
    if pyversion:
        self.first_run = False
    else:
        sys.exit(1)


def py_version_check() -> bool:
    """
    Python minimum version check
    :return: bool
    """
    try:
        if float(sys.version[:sys.version[2:].find('.') + 2]) < 3.10:
            print("Python version must be 3.10 or greater, buildpy.sh will build latest release from source")
            print("\nExiting...")
            return False
    except:
        if input("Python version check failed. Depends on 3.10 or greater, continue anyways(y/N?") == "":
            print("\nExiting...")
            return False

    return True
