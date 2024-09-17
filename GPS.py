"""
This provides GPS functionality
"""

from Globals import *
from Settings import Settings
import time


class GPS(Settings):
    """
    Initialize the GPS class.
    """

    def __init__(self):
        super().__init__()

    def gps_session(self, start: bool) -> bool:
        """
        True to start session. False to close session.
        :param start: bool
        :return: bool
        """
        if start:
            print("Starting GPS session...")
            if self.send_at("AT+CGPS=0,1", "OK", GPS_TIMEOUT) and self.send_at(
                "AT+CGPS=1,1", "OK", GPS_TIMEOUT
            ):
                print("Started successfully")
                time.sleep(2)
                return True
        if not start:
            print("Closing GPS session...")
            self.rec_buff = ""
            if self.send_at("AT+CGPS=0,1", "OK", GPS_TIMEOUT):
                return True
            else:
                return False

    def get_gps_position(self, retries: int = GPS_RETRY) -> str | bool:
        if self.gps_session(True):
            for _ in range(retries):
                answer = self.send_at("AT+CGPSINFO", "+CGPSINFO: ", GPS_TIMEOUT)
                if answer and ",,,,,," not in answer:
                    return answer
                elif ",,,,,," in answer:
                    print("GPS signal not found...")
                else:
                    print("Error accessing GPS, attempting to close session")
                    if not self.gps_session(False):
                        print("GPS was not found or did not close correctly")
                    else:
                        print("Done")
                    return False
            print("Retry limit reached; GPS signal not found...")
            return False
        else:
            print("Error starting GPS session")
