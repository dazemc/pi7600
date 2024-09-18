def get_message_type(message: str) -> str:
    message = message.rstrip().replace("\x00", "")

    try:
        # Try to interpret message as hexadecimal
        int(message, 16)
        message_b = bytes.fromhex(message)
        message = message_b.decode("utf-8")
    except ValueError:
        # Return original message if conversion fails
        pass

    return message


class Parser:
    def __init__(self):
        pass

    def parse_sms(self, sms_buffer: str) -> list:
        """
        Parses the modem sms buffer into a list of dictionaries
        :param sms_buffer: str
        :return: list<dict>
        """
        read_messages = sms_buffer.split("\r\n")
        print(read_messages)
        message_list = []


        for i in range(1, len(read_messages), 2):
            if len(read_messages[i]) > 1:
                message = read_messages[i].split(",")
                if len(message) >= 6:  # Ensure we have enough fields
                    print(message)
                    message_list.append(
                        {
                            "message_index": message[0][message[0].rfind(" ") + 1 :],
                            "message_type": get_message_type(
                                message[1].replace('"', "")
                            ),
                            "message_originating_address": get_message_type(
                                message[2].replace('"', "")
                            ),
                            "message_destination_address": get_message_type(
                                message[3].replace('"', "")
                            ),
                            "message_date": message[4][1:],  # Remove starting quote
                            "message_time": message[5][:-1],  # Remove trailing quote
                            "message_contents": get_message_type(
                                read_messages[i - 1]
                            ),  # Even index for message text
                        }
                    )
        return message_list
