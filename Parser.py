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
        read_messages = read_messages[1:-3]
        print(read_messages)
        message_list = []


        for i, v in enumerate(read_messages):
            if i % 2 == 0:
                message = v.split(",")
                print(message)
                print(v)
                message_list.append(
                    {
                        "message_index": message[0][message[0].rfind(" ") + 1 :],
                        "message_type":
                            message[1].replace('"', "")
                        ,
                        "message_originating_address":
                            message[2].replace('"', "")
                        ,
                        "message_destination_address":
                            message[3].replace('"', "")
                        ,
                        "message_date": message[4][1:],
                        "message_time": message[5][:-1],
                        "message_contents":
                            read_messages[i + 1]
                        ,
                    }
                )
        return message_list
