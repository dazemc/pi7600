import asyncio
import serial_asyncio


class SerialProtocol(asyncio.Protocol):
    def __init__(self, com: str, baudrate: int) -> None:
        super().__init__()
        self.transport = None
        self.write_queue = asyncio.Queue()  # Queue to hold outgoing commands
        self.com = com
        self.baudrate = baudrate
        # print(f"AT instance created with ID: {id(self)}")

    def connection_made(self, transport):
        print("Connection established.")
        self.transport = transport
        asyncio.create_task(self.process_write_queue())  # Start processing queue

    def data_received(self, data):
        return data.decode()

    def connection_lost(self, exc):
        print("Connection lost")
        asyncio.get_event_loop().stop()

    async def process_write_queue(self):
        while True:
            # Wait for the next item in the queue
            command, repeat = await self.write_queue.get()
            if self.transport.serial.cts:
                self.transport.write((command + "\r\n").encode())
                self.data_received(self.transport.serial.inw)
                if not repeat:
                    self.write_queue.task_done()
                else:
                    # Re-enqueue repeated commands with a delay
                    await asyncio.sleep(5)  # Delay between repeated sends
                    await self.write_queue.put((command, repeat))
            else:
                print("CTS is low, cannot send data now.")
            if not repeat:
                self.write_queue.task_done()

    async def send_data(self, data, repeat=False):
        """Enqueue data to be sent with an optional repeat flag."""
        await self.write_queue.put(
            (data, repeat)
        )  # Add data and repeat flag to the queue


async def main():
    loop = asyncio.get_running_loop()
    port = "/dev/ttyUSB2"
    baudrate = 115200

    try:
        transport, protocol = await serial_asyncio.create_serial_connection(
            loop,
            SerialProtocol,
            port,
            baudrate=baudrate,
            rtscts=True,
        )
    except Exception as e:
        print(f"Failed to connect: {e}")
        return

    # Add commands to the queue
    try:
        # Send a command only once
        await protocol.send_data(b"AT+CSQ\r\n", repeat=False)  # Sent only once

        await asyncio.sleep(1)  # Wait for a second

        # Send a command repeatedly every 5 seconds
        await protocol.send_data(b"AT+CREG?\r\n", repeat=True)  # Sent repeatedly

        await asyncio.sleep(1)

        # Send another single command
        await protocol.send_data(b"AT+CGATT?\r\n", repeat=False)  # Sent only once

    except KeyboardInterrupt:
        print("Program interrupted by user")
    finally:
        transport.close()


if __name__ == "__main__":
    asyncio.run(main())
