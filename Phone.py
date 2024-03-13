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

    def call(self, contact_number: str) -> bool:
        # TODO: Break into functions
        # init_checks(): Check for signal, network registration, open/incoming calls, etc
        # call_incoming(): Check for incoming calls
        # call(): Make a call
        # hangup_call(): Hangup a call
        # open_call(): Function executes during call, checking if call is still open
        # close_call(): Function executes after successful call
        try:
            while True:
                print(f"Attempting to call {contact_number}")
                #
                # These 3 commands are completely useless for establishing a call.
                # ATD will return an error code if there is no signal or network registration.
                # IF ATD returns an error then determine source of error.
                self.send_at('AT+CSQ', 'OK', PHONE_TIMEOUT)  # Check network quality
                self.send_at('AT+CREG?', 'OK', PHONE_TIMEOUT)  # Check network registration
                self.send_at('AT+CPSI?', 'OK', PHONE_TIMEOUT)  # Pretty much returns the previous two commands... Unnecessarily redundant?
                #
                #
                self.send_at('ATD' + contact_number + ';', 'OK', PHONE_TIMEOUT)
                input("Press enter to end call")
                self.ser.write('AT+CHUP\r\n'.encode())  # Hangup code, why is serial used vs send_at()?
                print('Call disconnected')
        except:
            return False
        finally:  # TODO: Proper return for current call
            return True
