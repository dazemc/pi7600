def get_message_type(message: str) -> str:
    try:
        int(message, 16)
        message_b = bytes.fromhex(message)
        message = message_b.decode("utf-8")
        return message.rstrip().replace("\x00", "")
    except:
        return message.rstrip().replace("\x00", "")


class Parser:
    def __init__(self):
        pass

    def parse_sms(self, sms_buffer: str) -> list:
        """
        Parses the modem buffer into list of dictionaries
        :param sms_buffer: str
        :return: list<dict>
        """
        read_messages = []
        for line in sms_buffer.split("\r\n"):
            read_messages.append(line)
        message_list = []
        message_data = [
            message.split(",")
            for i, message in enumerate(read_messages)
            if i % 2 != 0 and len(message) > 1
        ]
        message_text = [
            message for i, message in enumerate(read_messages) if i % 2 == 0 and i != 0
        ]
        for i, message in enumerate(message_data):
            message_list.append(
                {
                    # idx 0 is oldest message, this is relative to at+cmgd/cmgr
                    "message_index": message[0][message[0].rfind(" ") + 1 :],
                    "message_type": get_message_type(message[1].replace('"', "")),
                    "message_originating_address": get_message_type(
                        message[2].replace('"', "")
                    ),
                    "message_destination_address": get_message_type(
                        message[3].replace('"', "")
                    ),
                    "message_date": message[4][1:],
                    "message_time": message[5][:-1],
                    "message_contents": get_message_type(message_text[i]),
                }
            )
        return message_list
