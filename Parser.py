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
        message_list = []


        for i in read_messages:
            if len(i) > 1:
                message = i.split(",")
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
