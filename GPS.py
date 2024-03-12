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
        self.rec_buff = ''

    def gps_session(self, start: bool) -> bool:
        """
        True to start session. False to close session.
        :param start: bool
        :return: bool
        """
        if start:
            print('Starting GPS session...')
            if self.send_at('AT+CGPS=0', 'OK', GPS_TIMEOUT) and self.send_at('AT+CGPS=1', 'OK', GPS_TIMEOUT):
                time.sleep(2)
                return True
        if not start:
            print('Closing GPS session...')
            self.rec_buff = ''
            if self.send_at('AT+CGPS=0', 'OK', 1):
                return True
            else:
                return False

    def get_gps_position(self) -> str | bool:
        rec_buff = ''
        if self.gps_session(True):
            while True:
                answer = self.send_at('AT+CGPSINFO', '+CGPSINFO: ', 1)
                if answer and ',,,,,,' not in rec_buff:
                    return answer
                else:
                    print("Error accessing GPS, attempting to close session")
                    if not self.gps_session(False):
                        print("GPS was not found or did not close correctly")
                    else:
                        print("Done")
                    return False
        else:
            print("Error starting GPS session")
