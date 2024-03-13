from SMS import SMS
from GPS import GPS
from Phone import Phone
from Settings import Settings
from Globals import *

# SETTINGS
# settings = Settings()
# settings.enable_verbose_logging()  # Only needs to be enabled once

# GPS
# gps = GPS()
# gps_cor = gps.get_gps_position(GPS_RETRY)
# print(gps_cor)

# SMS
contact_number = "******"  # Number you sending to
# message = "Hello, world!"
# messaging = SMS()

# Read message lists, by message type ("ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT")
# buffer = messaging.read_message(message_type="ALL")
# print(buffer)

# Send message, returns True on success
# messaging.send_message(contact_number, message)

# PHONE
phone = Phone()
phone.call(contact_number)


