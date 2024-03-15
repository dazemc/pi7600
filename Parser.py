class Parser():
    def __init__(self):
        pass

    def parse_sms(self, sms_buffer: str) -> list:
        # TODO: Parse HEX automatically
        """
        Parses the modem buffer into list of dictionaries
        :param sms_buffer: str
        :return: list<dict>
        """
        read_messages = []
        for line in sms_buffer.split('\n'):
            read_messages.append(line)
        message_list = []
        message_data = [message.split(',') for i, message in enumerate(read_messages) if i % 2 != 0]
        message_text = [message for i, message in enumerate(read_messages) if i % 2 == 0 and i != 0]
        for i, message in enumerate(message_data):
            message_list.append({
                "message_index": message_data[1][0][-1],
                "message_type": message_data[1][1],
                "message_originating_address": message_data[1][2],
                "message_destination_address": message_data[1][3],
                "message_date": message_data[1][4][1:],
                "message_time": message_data[1][5][:-1],
                "message_contents": message_text[i]
            })
        message_final = message_list[:-1]
        return message_final
