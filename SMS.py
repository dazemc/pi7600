"""
This provides SMS functionality
"""

from Globals import *
from Settings import Settings


def parse_sms(sms_buffer: str) -> list:
    """
    Parses the modem sms buffer into a list of dictionaries
    :param sms_buffer: str
    :return: list<dict>
    """
    read_messages = sms_buffer.split("\r\n")
    read_messages = read_messages[
        1:-3
    ]  # first and last few values are just cmd and resp code
    message_list = []

    for i, v in enumerate(read_messages):
        if i % 2 == 0:  # Even idx has msg info, odd is msg content for preceding idx
            message = v.split(",")
            message_list.append(
                {
                    "message_index": message[0][message[0].rfind(" ") + 1 :],
                    "message_type": message[1].replace('"', ""),
                    "message_originating_address": message[2].replace('"', ""),
                    "message_destination_address": message[3].replace('"', ""),
                    "message_date": message[4][1:],
                    "message_time": message[5][:-1],
                    "message_contents": read_messages[
                        i + 1
                    ],  # idx + 1 is always message content
                }
            )
    return message_list


class SMS(Settings):
    """
    Initialize the SMS class.
    """

    def __init__(self):
        super().__init__()

    def receive_message(self, message_type: str) -> list:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: list<dict>
        """
        # self.set_data_mode(1)
        answer = self.send_at(f'AT+CMGL="{message_type}"', "OK", TIMEOUT)
        if answer:
            if message_type != "ALL" and message_type in answer:
                answer = parse_sms(answer)
                return answer
            elif message_type == "ALL":
                answer = parse_sms(answer)
                return answer
            else:
                print(f"AT command failed, returned the following:\n{answer}")

    def read_message(self, message_type: str) -> list:
        """
        Reads message from specified message type.
        :param message_type: str
        :return: list<dict>
        """
        try:
            buffer = self.receive_message(message_type)
            return {"response": buffer}
        except Exception as e:
            print("Error:", e)
            if self.ser is not None:
                self.ser.close()

    def loop_for_messages(self, message_type: str) -> list:
        """
        Starts a loop that reads message(s) from specified message type.
        :param message_type: str
        :return: str
        """
        while True:
            try:
                buffer = self.receive_message(message_type)
                return buffer
            except Exception as e:
                print(f"Unhandled error: {e}")
                if self.ser is not None:
                    self.ser.close()

    def send_message(self, phone_number: str, text_message: str) -> bool:
        answer = self.send_at('AT+CMGS="' + phone_number + '"', ">", TIMEOUT)
        if answer:
            self.ser.write(text_message.encode())
            self.ser.write(b"\x1a")
            # 'OK' here means the message sent?
            answer = self.send_at("", "OK", SMS_SEND_TIMEOUT)
            if answer:
                print(
                    f"Number: {phone_number}\n"
                    f"Message: {text_message}\n"
                    f"Message sent!"
                )
                return True
            else:
                print(
                    f"Error sending message...\n"
                    f"phone_number: {phone_number}\n"
                    f"text_message: {text_message}\n"
                    f"Not sent!"
                )
                return False
        else:
            print(f"error: {answer}")
            return False

    def delete_message(self, msg_idx: int) -> dict:
        """delete message by index

        Args:
            msg_idx (int): message to delete

        Returns:
            dict: {"response": "Success" | False}
        """
        resp = self.send_at(f"AT+CMGD={msg_idx}", "OK", TIMEOUT)
        if resp:
            return {"response": "Success"}
        else:
            return {"response": False}
