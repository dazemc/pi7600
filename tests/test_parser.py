from pi7600.ParserSMS import Parser, status

TEXT_BUFFER = (
    '\r\n+CMGL: 1,"REC READ","+15551234567","","24/01/01,12:00:00+00"'
    "\r\nHello"
    '\r\n+CMGL: 2,"REC UNREAD","+15557654321","","24/01/01,13:00:00+00"'
    "\r\nWorld"
    "\r\n\r\nOK\r\n"
)

PDU = "07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07"
PDU_BUFFER = f"\r\n+CMGL: 1,0,,26\r\n{PDU}\r\n\r\nOK\r\n"


def test_status_values():
    assert status("0") == "REC UNREAD"
    assert status("1") == "REC READ"
    assert status("2") == "STO UNSENT"
    assert status("3") == "STO SENT"
    assert status("9") == "UNKNOWN"


def test_parse_text_returns_all_messages():
    parser = Parser(timezone=0)
    messages = parser.parse_sms(TEXT_BUFFER)
    assert len(messages) == 2
    assert messages[0].message_index == "1"
    assert messages[0].message_contents == "Hello"
    assert messages[1].message_index == "2"
    assert messages[1].message_contents == "World"


def test_parse_text_empty_buffer():
    parser = Parser(timezone=0)
    assert parser.parse_sms("") == []


def test_parse_pdu_single_message():
    parser = Parser(timezone=0)
    messages = parser.parse_pdu(PDU_BUFFER)
    assert len(messages) == 1
    message = messages[0]
    assert message.message_index == "1"
    assert message.message_type == "REC UNREAD"
    assert message.message_originating_address == "+31641600986"
    assert message.message_contents == "How are you?"
    assert message.in_sim_memory is True
    assert message.is_partial is False


def test_parse_pdu_unknown_status():
    parser = Parser(timezone=0)
    buffer = f"\r\n+CMGL: 1,9,,26\r\n{PDU}\r\n\r\nOK\r\n"
    messages = parser.parse_pdu(buffer)
    assert messages[0].message_type == "UNKNOWN"


def test_parse_pdu_empty_buffer():
    parser = Parser(timezone=0)
    assert parser.parse_pdu("") == []
    assert parser.parse_pdu("+CMGL: ") == []
