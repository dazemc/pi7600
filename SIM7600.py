from SMS import SMS

contact_number = "******"
messaging = SMS(contact_number)
buffer = messaging.read_message(message_type="ALL")
print(buffer)
