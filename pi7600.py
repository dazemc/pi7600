import asyncio
import sys
import time

import serial

BUFFER_CHAR_LIMIT = 559  # "AT" prefix does not count
EXIT_SUCCESS_CODE = 0
EXIT_FAILURE_CODE = 1
TIMEOUT = 3
SMS_SEND_TIMEOUT = 15
BUFFER_WAIT_TIME = 0.01
GPS_TIMEOUT = 1
GPS_RETRY = 10
PHONE_TIMEOUT = 1
BAUDRATE = 115200
COM = "/dev/ttyUSB2"
WATCHER_COM = "/dev/ttyUSB3"
POLL = 5


def py_version_check() -> bool:
    """
    Python minimum version check (3.10)
    :return: bool
    """
    try:
        if float(sys.version[: sys.version[2:].find(".") + 2]) < 3.10:
            print("Python version must be 3.10 or greater")
            print("\nExiting...")
            return False
    except:
        user_input = input(
            "Python version check failed. Depends on 3.10 or greater, continue anyways(y/N?"
        ).lower()
        if user_input in ["", "n"]:
            print("\nExiting...")
            return False
    return True


class SingletonMeta(type):
    """
    This metaclass ensures that only one instance of any class using it exists.
    """

    _instances = {}  # Dictionary to hold single instances

    def __call__(cls, *args, **kwargs):
        """
        If an instance of cls doesn't exist, create one and store it in _instances.
        Otherwise, return the existing instance.
        """
        if cls not in cls._instances:
            # print(f"Creating new instance of {cls.__name__}")
            cls._instances[cls] = super(SingletonMeta, cls).__call__(*args, **kwargs)
        else:
            # print(f"Using existing instance of {cls.__name__}")
            pass
        return cls._instances[cls]


class AT:
    def __init__(self, com: str, baudrate: int) -> None:
        self.com = com
        self.baudrate = baudrate
        self.ser = self.init_serial(baudrate, com)
        self.rec_buff = ""
        self.write_queue = asyncio.Queue()  # Queue for managing outgoing commands
        self.task = None  # Task for processing the write queue

    def init_serial(self, baud, com):
        ser = serial.Serial(com, baud, rtscts=True, timeout=0.5)
        return ser

    async def send_at(self, command: str, back: str, timeout: int) -> str:
        """
        Send an AT command and wait for the expected response.
        :param command: str - AT command to be sent
        :param back: str - Expected response to check
        :param timeout: int - Timeout to wait for a response
        :return: str - The response from the device, or an error message.
        """
        if self.task is None or self.task.done():
            self.task = asyncio.create_task(self.process_write_queue())
        self.clear_buffer()
        self.ser.write((command + "\r\n").encode())
        start_time = time.time()
        while True:
            if self.ser.in_waiting > 0:
                self.rec_buff += self.ser.read(self.ser.in_waiting).decode(
                    errors="ignore"
                )
            if back in self.rec_buff:
                response = self.rec_buff
                self.clear_buffer()
                return response
            if time.time() - start_time > timeout:
                self.clear_buffer()
                return f"ERROR: Timeout while waiting for response to '{command}'"

            # Yield control to other tasks and wait a bit before checking again
            await asyncio.sleep(0.1)

    async def process_write_queue(self):
        """
        Asynchronously process the write queue and send commands.
        """
        while True:
            command, back, timeout, repeat = await self.write_queue.get()
            response = await self.send_at(command, back, timeout)
            if "ERROR" in response:
                print(f"Failed to execute: {command}, Error: {response}")
            else:
                print(f"Successfully executed: {command}, Response: {response}")

            # Re-enqueue if repeat is True
            if repeat:
                await asyncio.sleep(POLL)
                await self.write_queue.put((command, back, timeout, repeat))

            # Mark task as done if not repeating
            if not repeat:
                self.write_queue.task_done()

    def close_serial(self) -> None:
        try:
            self.ser.close()
        except:
            print("Failed to close serial: Already closed or inaccessible")

    def clear_buffer(self) -> None:
        if self.ser.in_waiting:
            self.ser.flush()
        self.rec_buff = ""


class Settings(metaclass=SingletonMeta):
    def __init__(self, com=COM, baudrate=BAUDRATE) -> None:
        """
        Initializes Settings class
        :param port: str
        :param baudrate: int
        """
        self.at = AT(com=com, baudrate=baudrate)
        self.first_run = True

    def __getattr__(self, name):
        try:
            return getattr(self.at, name)
        except AttributeError:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )

    async def perform_initial_checks(self) -> None:
        """
        Initial environment checks asynchronously.
        """
        checks = {
            "Python version requirements not met": lambda: py_version_check(),
            "SIM device not ready": lambda: self.sim_ready_check(),
        }
        check_failed = False
        for check, result_function in checks.items():
            result = await result_function()  # Await the result from the function
            if result is False:
                check_failed = True
                print(check)
        if check_failed:
            sys.exit(EXIT_FAILURE_CODE)
        else:
            self.first_run = False

    async def enable_verbose_logging(self) -> bool:
        if await self.send_at("AT+CMEE=2", "OK", TIMEOUT):
            return True
        return False

    async def sim_ready_check(self) -> bool:
        if await self.send_at("AT+CPIN?", "READY", TIMEOUT):
            return True
        return False

    async def get_config(self) -> str | bool:
        if await self.send_at("AT&V", "OK", TIMEOUT):
            return True
        return False

    async def set_usb_os(self, os: str) -> bool:
        """
        USB setting for RNDIS, OS specific. "WIN" or "UNIX".
        :param os: str
        :return: bool
        """
        if os == "WIN":
            await self.send_at("AT+CUSBPIDSWITCH=9001,1,1", "OK", TIMEOUT)
        elif os == "UNIX":
            await self.send_at("AT+CUSBPIDSWITCH=9011,1,1", "OK", TIMEOUT)
        for _ in range(6):  # Wait up to 3 mins for reboot
            time.sleep(30)
            try:
                self.init_serial(BAUDRATE, COM)
                if await self.send_at("AT", "OK", TIMEOUT):
                    print(f"Set usb for {os}")
                    return True
            except:
                print("Waiting for device to reboot...")
        print("Failed to set USB mode.")
        return False

    async def set_sms_storage(self, mode: str) -> bool:
        """
        Set SMS storage location
        :param mode: str
        :return: bool
        """
        if await self.send_at(
            f'AT+CPMS="{mode}","{mode}","{mode}"', "OK", TIMEOUT
        ):  # Store messages on SIM(SM), "ME"/"MT" is flash
            return True
        return False

    async def set_data_mode(self, mode: int) -> None:
        """
        HEX is automatically used if there is data issues, such as low signal quality.
        :param mode: int
        :return: None
        """
        if mode == 1:
            await self.send_at("AT+CMGF=1", "OK", TIMEOUT)  # Set to text mode
        if mode == 0:
            await self.send_at("AT+CMGF=0", "OK", TIMEOUT)  # Set to hex mode

    async def set_encoding_mode(self, mode: int) -> None:
        """
        Set encoding mode. 0=IRA, 1=GSM, 2=UCS2
        :param mode: int
        :return: None
        """
        if mode == 2:
            await self.send_at('AT+CSCS="UCS2"', "OK", TIMEOUT)
        if mode == 1:
            await self.send_at('AT+CSCS="GSM"', "OK", TIMEOUT)
        if mode == 0:
            await self.send_at('AT+CSCS="IRA"', "OK", TIMEOUT)


class GPS:
    """
    Initialize the GPS class.
    """

    def __init__(self):
        self.settings = Settings()
        self.loc = ""
        self.is_running = False  # Initialized to False; actual status will be checked asynchronously later

    def __getattr__(self, name):
        try:
            return getattr(self.settings, name)
        except AttributeError:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )

    async def session_check(self):
        check = await self.send_at("AT+CGPS?", "+CGPS", TIMEOUT)
        self.is_running = True if "+CGPS: 1,1" in check else False
        return self.is_running

    async def gps_session(self, start: bool) -> bool:
        """
        True to start session. False to close session.
        :param start: bool
        :return: bool
        """
        await self.session_check()
        if start:
            print("Starting GPS session...")
            if await self.send_at(
                "AT+CGPS=0,1", "OK", GPS_TIMEOUT
            ) and await self.send_at("AT+CGPS=1,1", "OK", GPS_TIMEOUT):
                print("Started successfully")
                await asyncio.sleep(2)
                self.is_running = True
                return True
        else:
            print("Closing GPS session...")
            self.rec_buff = ""
            if await self.send_at("AT+CGPS=0,1", "OK", GPS_TIMEOUT):
                self.is_running = False
                return True
            else:
                print("Error closing GPS, is it open?")
                return False

    async def get_gps_position(self, retries: int = GPS_RETRY) -> str | bool:
        await self.session_check()  # Ensure session status is checked asynchronously
        if self.is_running:
            for _ in range(retries):
                answer = await self.send_at("AT+CGPSINFO", "+CGPSINFO: ", GPS_TIMEOUT)
                if answer and ",,,,,," not in answer:
                    return answer
                elif ",,,,,," in answer:
                    return "GPS is active but no signal was found"
                else:
                    print("Error accessing GPS, attempting to close session")
                    if not await self.gps_session(False):  # Await the async method
                        print("GPS was not found or did not close correctly")
                    else:
                        print("Done")
                    return False
            print("Retry limit reached; GPS signal not found...")
            return False
        else:
            print(
                "Attempting to get location without an open GPS session, trying to open one now..."
            )
            await self.gps_session(True)  # Await the async method
            return await self.get_gps_position()  # Await the async recursive call


def parse_sms(sms_buffer: str) -> list:
    """
    Parses the modem sms buffer into a list of dictionaries
    :param sms_buffer: str
    :return: list<dict>
    """
    read_messages = sms_buffer.split("\r\n")
    read_messages = read_messages[
        1:-3
    ]  # first and last few values are just cmd and resp code
    message_list = []

    for i, v in enumerate(read_messages):
        if i % 2 == 0:  # Even idx has msg info, odd is msg content for preceding idx
            message = v.replace('"', "", 9).split(",")
            message_list.append(
                {
                    "message_index": message[0][message[0].rfind(" ") + 1 :],
                    "message_type": message[1],
                    "message_originating_address": message[2],
                    "message_destination_address": message[3],
                    "message_date": message[4][1:],
                    "message_time": message[5][:-1],
                    "message_contents": read_messages[
                        i + 1
                    ],  # idx + 1 is always message content
                }
            )
    return message_list


class Phone:
    """
    Initialize the Phone class.
    """

    def __init__(self):
        self.settings = Settings()

    def __getattr__(self, name):
        try:
            return getattr(self.settings, name)
        except AttributeError:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )

    async def hangup_call(self) -> bool:
        if await self.send_at("AT+CHUP", "OK", PHONE_TIMEOUT):
            return True
        return False

    def call_incoming(self):
        # call_incoming(): Check for incoming calls
        # I will come back to this after I determine concurrency/interrupts/chaining AT commands
        pass

    async def active_calls(self) -> str | bool:
        """
        Returns information on any active calls
        :return: str || bool
        """
        if await self.send_at("AT+CLCC?", "OK", PHONE_TIMEOUT):
            return True
        return False

    async def call(self, contact_number: str, retry: int = 0) -> bool:
        """
        Start outgoing call.
        :param contact_number: str
        :param retry: int
        :return: bool
        """
        # A True return does not mean call was connected, simply means the attempt was valid without errors.
        attempt = 1
        try:
            while True:
                print(
                    f"Attempting to call {contact_number}; Attempt: {attempt}; Retry: {retry}"
                )
                # IF ATD returns an error then determine source of error.
                if await self.send_at(
                    "ATD" + contact_number + ";", "OK", PHONE_TIMEOUT
                ):
                    input("Call connected!\nPress enter to end call")
                    # self.ser.write('AT+CHUP\r\n'.encode())  # Hangup code, why is serial used vs send_at()?
                    self.hangup_call()
                    print("Call disconnected")
                    return True
                elif retry == 0 or attempt == retry:
                    return True
                elif retry != 0:
                    print(
                        f"Retrying call to {contact_number}; Attempt: {attempt}/{retry}"
                    )
                    attempt += 1
        except:
            return False

    def closed_call(self) -> str:
        # This will display information about calls that have been made/attempted
        # Call time, connection status, error outputs, etc
        pass


class SMS:
    """
    Initialize the SMS class.
    """

    def __init__(self):
        self.settings = Settings()

    def __getattr__(self, name):
        try:
            return getattr(self.settings, name)
        except AttributeError:
            raise AttributeError(
                f"'{type(self).__name__}' object has no attribute '{name}'"
            )

    async def receive_message(self, message_type: str) -> list:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: list<dict>
        """
        # self.set_data_mode(1)
        answer = await self.send_at(f'AT+CMGL="{message_type}"', "OK", TIMEOUT)
        if answer:
            if message_type != "ALL" and message_type in answer:
                answer = parse_sms(answer)
                return answer
            elif message_type == "ALL":
                answer = parse_sms(answer)
                return answer
            else:
                print(f"AT command failed, returned the following:\n{answer}")

    def read_message(self, message_type: str) -> list:
        """
        Reads message from specified message type.
        :param message_type: str
        :return: list<dict>
        """
        try:
            buffer = self.receive_message(message_type)
            return buffer
        except Exception as e:
            print("Error:", e)
            if self.ser is not None:
                self.ser.close()

    def loop_for_messages(self, message_type: str) -> list:
        """
        Starts a loop that reads message(s) from specified message type.
        :param message_type: str
        :return: str
        """
        while True:
            try:
                buffer = self.receive_message(message_type)
                return buffer
            except Exception as e:
                print(f"Unhandled error: {e}")
                if self.ser is not None:
                    self.ser.close()

    async def send_message(self, phone_number: str, text_message: str) -> bool:
        answer = await self.send_at('AT+CMGS="' + phone_number + '"', ">", TIMEOUT)
        if answer:
            self.ser.write(text_message.encode())
            self.ser.write(b"\x1a")
            # 'OK' here means the message sent?
            answer = await self.send_at("", "OK", SMS_SEND_TIMEOUT)
            if answer:
                print(
                    f"Number: {phone_number}\n"
                    f"Message: {text_message}\n"
                    f"Message sent!"
                )
                return True
            else:
                print(
                    f"Error sending message...\n"
                    f"phone_number: {phone_number}\n"
                    f"text_message: {text_message}\n"
                    f"Not sent!"
                )
                return False
        else:
            print(f"error: {answer}")
            return False

    async def delete_message(self, msg_idx: int) -> dict:
        """delete message by index

        Args:
            msg_idx (int): message to delete

        Returns:
            dict: {"response": "Success" | False}
        """
        resp = await self.send_at(f"AT+CMGD={msg_idx}", "OK", TIMEOUT)
        if resp:
            return {"response": "Success"}
        else:
            return {"response": False}
