# TODO: Better error handling and logging
"""
This provides SMS functionality
"""
from Globals import *
from Settings import Settings


class SMS(Settings):
    """
    Initialize the SMS class.
    """

    def __init__(self):
        super().__init__()

    def receive_message(self, message_type: str) -> str:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: str
        """
        self.set_data_mode(1)
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

    def send_message(self, phone_number: str, text_message: str) -> bool:
        answer = self.send_at("AT+CMGS=\"" + phone_number + "\"", ">", TIMEOUT)
        if answer:
            self.ser.write(text_message.encode())
            self.ser.write(b'\x1A')
            answer = self.send_at('', 'OK', SMS_SEND_TIMEOUT)  # 'OK' here means the message sent?
            if answer:
                print(
                    f'Number: {phone_number}\n'
                    f'Message: {text_message}\n'
                    f'Message sent!')
                return True
            else:
                print(
                    f'Error sending message...\n'
                    f'phone_number: {phone_number}\n'
                    f'text_message: {text_message}\n'
                    f'Not sent!')
                return False
        else:
            print('error%d' % answer)
            return False
