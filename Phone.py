"""
Provides Phone-call functionality
"""

import time
from Globals import *
from Settings import Settings


class Phone(Settings):
    """
    Initialize the Phone class.
    """

    def __init__(self):
        super().__init__()

    def init_checks(self):
        pass
        # self.send_at('AT+CSQ', 'OK', PHONE_TIMEOUT)  # Check network quality
        # self.send_at('AT+CREG?', 'OK', PHONE_TIMEOUT)  # Check network registration
        # self.send_at('AT+CPSI?', 'OK',PHONE_TIMEOUT)  # Pretty much returns the previous two commands... Unnecessarily redundant?

    def hangup_call(self) -> bool:
        self.rec_buff = self.send_at("AT+CHUP", "OK", PHONE_TIMEOUT)
        if self.rec_buff:
            return True
        else:
            print("Unknown error ending call. Is serial open?")
            return False

    def call_incoming(self):
        # call_incoming(): Check for incoming calls
        # I will come back to this after I determine concurrency/interrupts/chaining AT commands
        pass

    def active_calls(self) -> str | bool:
        """
        Returns information on any active calls
        :return: str || bool
        """
        self.rec_buff = self.send_at("AT+CLCC?", "OK", PHONE_TIMEOUT)
        if self.rec_buff:
            return self.rec_buff
        else:
            print("Error checking active calls")
            return False

    def call(self, contact_number: str, retry: int = 0) -> bool:
        """
        Start outgoing call.
        :param contact_number: str
        :param retry: int
        :return: bool
        """
        # A True return does not mean call was connected, simply means the attempt was valid without errors.
        attempt = 1
        try:
            while True:
                print(
                    f"Attempting to call {contact_number}; Attempt: {attempt}; Retry: {retry}"
                )
                # IF ATD returns an error then determine source of error.
                if self.send_at("ATD" + contact_number + ";", "OK", PHONE_TIMEOUT):
                    input("Call connected!\nPress enter to end call")
                    # self.ser.write('AT+CHUP\r\n'.encode())  # Hangup code, why is serial used vs send_at()?
                    self.hangup_call()
                    print("Call disconnected")
                    return True
                elif retry == 0 or attempt == retry:
                    return True
                elif retry != 0:
                    print(
                        f"Retrying call to {contact_number}; Attempt: {attempt}/{retry}"
                    )
                    attempt += 1
        except:
            return False

    def closed_call(self) -> str:
        # This will display information about calls that have been made/attempted
        # Call time, connection status, error outputs, etc
        pass
