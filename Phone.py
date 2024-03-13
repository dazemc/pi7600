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
        try:
            while True:
                self.send_at('AT+CSQ', 'OK', PHONE_TIMEOUT)
                self.send_at('AT+CREG?', 'OK', PHONE_TIMEOUT)
                self.send_at('AT+CPSI?', 'OK', PHONE_TIMEOUT)
                self.send_at('ATD' + contact_number + ';', 'OK', PHONE_TIMEOUT)
                time.sleep(20)
                self.ser.write('AT+CHUP\r\n'.encode())
                print('Call disconnected')
                return True
        except:
            return False
