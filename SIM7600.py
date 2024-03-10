from SMS import SMS
from Settings import Settings

# settings = Settings()
# settings.enable_verbose_logging()  # Only needs to be enabled once

contact_number = "******"  # Number you sending to
message = "Hello, world!"
messaging = SMS()

# Read message lists, by message type ("ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT")
buffer = messaging.read_message(message_type="ALL")
print(buffer)

# Send message, returns True on success
messaging.send_message(contact_number, message)