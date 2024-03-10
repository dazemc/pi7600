"""
This provides SMS functionality
"""
import time
from Settings import *
from Globals import *


# import RPi.GPIO as GPIO

# TODO: Send message!
class SMS(Settings):
    """
    Initialize the SMS class.
    """

    def __init__(self, contact_number):
        super().__init__(COM, BAUDRATE)
        self.phone_number = contact_number  # Number you are contacting
        self.rec_buff = ''

    def send_at(self, command: str, back: str, timeout: int) -> bool | str:
        """
        Send AT commands over serial. Returns 'False' on error or str on success.
        :param command: str
        :param back: str
        :param timeout: int
        :return: bool | str
        """
        self.rec_buff = ''
        self.ser.write((command + '\r\n').encode())
        time.sleep(timeout)
        if self.ser.inWaiting():
            time.sleep(BUFFER_WAIT_TIME)
            self.rec_buff = self.ser.read(self.ser.inWaiting())
        if back not in self.rec_buff.decode():
            print(command + ' ERROR')
            print(command + ' back:\t' + self.rec_buff.decode())
            return False
        else:
            return self.rec_buff.decode()

    def receive_message(self, message_type: str) -> str:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: str
        """
        answer = self.send_at(f'AT+CMGL="{message_type}"', 'OK', TIMEOUT)
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
