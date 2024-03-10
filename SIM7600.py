from SMS import SMS
from Settings import Settings

settings = Settings()
settings.enable_verbose_logging()

contact_number = "******"
messaging = SMS(contact_number)
buffer = messaging.read_message(message_type="ALL")
print(buffer)
