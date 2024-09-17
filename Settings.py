# TODO: Try to close any open serial connections if COM port fails
"""
This provides Settings for all modules
"""
import sys
import time
from Globals import *
from AT import AT


def py_version_check() -> bool:
    """
    Python minimum version check (3.10)
    :return: bool
    """
    try:
        if float(sys.version[: sys.version[2:].find(".") + 2]) < 3.10:
            print(
                "Python version must be 3.10 or greater, buildpy.sh will build latest stable release from source. "
                "Alternatively, you can use the included venv with ./venv/Scripts/activate"
            )
            print("\nExiting...")
            return False
    except:
        user_input = input(
            "Python version check failed. Depends on 3.10 or greater, continue anyways(y/N?"
        ).lower()
        if user_input in ["", "n"]:
            print("\nExiting...")
            return False
    return True


class Settings(AT):
    def __init__(self) -> None:
        super().__init__(com=COM, baudrate=BAUDRATE)
        """
        Initializes Settings class
        :param port: str
        :param baudrate: int
        """
        self.first_run = True
        if self.first_run:
            self.perform_initial_checks()

    def perform_initial_checks(self) -> None:
        """
        Initial environment checks
        :param self:
        :return: None
        """
        checks = {
            "Python version requirements not met": lambda: py_version_check(),
            "SIM device not ready": lambda: self.sim_ready_check(),
        }
        check_failed = False
        for check, result_function in checks.items():
            result = (
                result_function()
            )  # Call the lambda function to execute the actual check
            if result is False:
                check_failed = True
                print(check)
        if check_failed:
            sys.exit(EXIT_FAILURE_CODE)
        else:
            self.first_run = False

    def enable_verbose_logging(self) -> bool:
        self.rec_buff = self.send_at("AT+CMEE=2", "OK", TIMEOUT)
        if self.rec_buff:
            return True
        else:
            return False

    def sim_ready_check(self) -> bool:
        buffer = self.send_at("AT+CPIN?", "READY", TIMEOUT)
        if buffer:
            return True
        else:
            return False

    def get_config(self) -> str | bool:
        self.rec_buff = self.send_at("AT&V", "OK", TIMEOUT)
        if self.rec_buff:
            return self.rec_buff
        else:
            return False

    def set_usb_os(self, os: str) -> bool:
        """
        USB setting for RNDIS, OS specific. "WIN" or "UNIX".
        :param os: str
        :return: bool
        """
        if os == "WIN":
            self.send_at("AT+CUSBPIDSWITCH=9001,1,1", "OK", TIMEOUT)
        elif os == "UNIX":
            self.send_at("AT+CUSBPIDSWITCH=9011,1,1", "OK", TIMEOUT)
        for _ in range(6):  # Wait up to 3 mins for reboot
            time.sleep(30)
            try:
                self.init_serial(BAUDRATE, COM)
                if self.send_at("AT", "OK", TIMEOUT):
                    print(f"Set usb for {os}")
                    return True
            except:
                print("Waiting for device to reboot...")
        print("Failed to set USB mode.")
        return False

    def set_sms_storage(self, mode: str) -> bool:
        """
        Set SMS storage location
        :param mode: str
        :return: bool
        """
        buffer = self.send_at(
            f'AT+CPMS="{mode}","{mode}","{mode}"', "OK", TIMEOUT
        )  # Store messages on SIM(SM), "ME"/"MT" is flash
        if buffer:
            return True
        else:
            return False

    def set_data_mode(self, mode: int) -> None:
        """
        HEX is automatically used if there is data issues, such as low signal quality.
        :param mode: int
        :return: None
        """
        if mode == 1:
            self.send_at("AT+CMGF=1", "OK", TIMEOUT)  # Set to text mode
        if mode == 0:
            self.send_at("AT+CMGF=0", "OK", TIMEOUT)  # Set to hex mode

    def set_encoding_mode(self, mode: int) -> None:
        """
        Set encoding mode. 0=IRA, 1=GSM, 2=UCS2
        :param mode: int
        :return: None
        """
        if mode == 2:
            self.send_at('AT+CSCS="UCS2"', "OK", TIMEOUT)
        if mode == 1:
            self.send_at('AT+CSCS="GSM"', "OK", TIMEOUT)
        if mode == 0:
            self.send_at('AT+CSCS="IRA"', "OK", TIMEOUT)
