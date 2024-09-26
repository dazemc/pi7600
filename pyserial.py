import asyncio
import serial_asyncio

class SerialReader(asyncio.Protocol):
    def connection_made(self, transport):
        print("Connection established.")
        self.transport = transport
        print(f"Port settings: {self.transport.serial}")

    def data_received(self, data):
        print(f"Data received: {data.decode(errors='ignore').strip()}")

    def connection_lost(self, exc):
        print("Connection lost")
        if exc:
            print(f"Error: {exc}")
        self.transport.loop.stop()

async def main():
    loop = asyncio.get_running_loop()

    # Adjust the port and baudrate according to your setup
    port = '/dev/ttyUSB3'  # Adjust to your correct port
    baudrate = 115200        # Adjust to your correct baudrate

    # Create a serial connection with hardware flow control enabled
    try:
        transport, protocol = await serial_asyncio.create_serial_connection(
            loop,
            SerialReader,
            port,
            baudrate=baudrate,
            rtscts=True,  # Enable hardware flow control
        )
        print(f"Connected to {port} at {baudrate} baudrate with RTS/CTS enabled")
    except Exception as e:
        print(f"Failed to connect to {port}: {e}")
        return

    try:
        await asyncio.sleep(3600)  # Run for 1 hour, adjust as needed
    except KeyboardInterrupt:
        print("Program interrupted")
    finally:
        print("Closing transport")
        transport.close()

if __name__ == "__main__":
    asyncio.run(main())

