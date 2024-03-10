"""
This provides SMS functionality
"""
from AT import AT
from Globals import *

at = AT()


# import RPi.GPIO as GPIO

# TODO: Send message!
class SMS:
    """
    Initialize the SMS class.
    """

    def __init__(self, contact_number):
        self.phone_number = contact_number  # Number you are contacting
        self.rec_buff = ''

    def receive_message(self, message_type: str) -> str:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: str
        """
        answer = at.send_at(f'AT+CMGL="{message_type}"', 'OK', TIMEOUT)
        if answer:
            if message_type != "ALL" and message_type in answer:
                return answer
            elif message_type == "ALL":
                return answer
            else:
                print(f"AT command failed, returned the following:\n{answer}")

    def read_message(self, message_type: str) -> str:
        """
        Reads message from specified message type.
        :param message_type: str
        :return: str
        """
        try:
            buffer = self.receive_message(message_type)
            return buffer
        except:
            if self.ser is not None:
                self.ser.close()

    def loop_for_messages(self, message_type: str) -> str:
        """
                Starts a loop that reads message(s) from specified message type.
                :param message_type: str
                :return: str
                """
        while True:
            try:
                buffer = self.receive_message(message_type)
                return buffer
            except:
                if self.ser is not None:
                    self.ser.close()
                    sys.exit(EXIT_SUCCESS_CODE)
                # GPIO.cleanup()
