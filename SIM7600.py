from SMS import SMS

contact_number = "******"
messaging = SMS(contact_number)
received_buffer = messaging.read_message(message_type="ALL")
print(received_buffer)
