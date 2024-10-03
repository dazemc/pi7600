# Pi7600: Python Library and REST API for SIM7600G-H 4G HAT

[GitHub Repository](https://github.com/dazemc/pi7600)

## Overview

**Pi7600** is a Python library and FastAPI-based REST API for managing the [SIM7600G-H 4G HAT from Waveshare](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B)) on systems like the Raspberry Pi. The project enables various operations for modem control, including:

- Checking modem information and status
- Retrieving host system details
- Managing SMS messages (send, read, delete)
- Executing raw AT commands
- Accessing GPS data

This tool integrates various modules such as `GPS`, `SMS`, and `Settings` to provide comprehensive control over the modem, all while supporting asynchronous execution for improved performance.

## Features

- **Modem Information**: Retrieve network and device status asynchronously.
- **Host System Information**: Fetch system details like hostname, kernel version, and architecture.
- **SMS Management**: Send, read, and delete SMS messages with asynchronous support.
- **AT Command Interface**: Execute raw AT commands and get modem responses asynchronously.
- **GPS Data**: Access GPS coordinates via the SIM7600 module asynchronously.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [API Endpoints](#api-endpoints)
  - [Modem Status `/`](#modem-status-)
  - [Host Information `/info`](#host-information-info)
  - [SMS Management `/sms`](#sms-management-sms)
    - [Read SMS `GET /sms`](#read-sms-get-sms)
    - [Send SMS `POST /sms`](#send-sms-post-sms)
    - [Delete SMS `DELETE /sms/delete/{msg_idx}`](#delete-sms-delete-smsdelete-msg_idx)
  - [AT Command Interface `/at`](#at-command-interface-at)
  - [API Documentation `/docs` and `/redoc`](#api-documentation-docs-and-redoc)
- [Resources](#resources)
- [Contributing](#contributing)
- [License](#license)

## Installation

*Detailed installation instructions will be provided in the future once the project reaches a stable release.*

## Usage

To run the API, use the FastAPI server powered by `uvicorn`:

```bash
uvicorn main:app --reload
```

This starts the API server at `http://localhost:8000`.

## API Endpoints

### Modem Status `/`

- **Method**: `GET`
- **Description**: Returns modem information, including AT command checks, signal quality, SIM status, network registration, and GPS info.

**Example Request**:

```bash
curl -X GET http://localhost:8000/
```

**Response**:
```json
{
  "at": "OK",
  "cnum": "+11234567890",
  "csq": "+CSQ: 15,99",
  "cpin": "+CPIN: READY",
  "creg": "+CREG: 0,1",
  "cops": "+COPS: 0,0,\"Carrier\",7",
  "gpsinfo": "GPS is active but no signal was found",
  "data": "OK",
  "dns": "OK",
  "apn": "fast.t-mobile.com"
}
```

### Host Information `/info`

- **Method**: `GET`
- **Description**: Fetches host system details like hostname, kernel version, and architecture.

**Example Request**:

```bash
curl -X GET http://localhost:8000/info
```

**Response**:
```json
{
  "hostname": "raspberrypi",
  "uname": "5.10.17-v7l+",
  "date": "Tue Sep 17 22:48:47 2024",
  "arch": "armv7l"
}
```

### SMS Management `/sms`

#### Read SMS `GET /sms`

- **Method**: `GET`
- **Description**: Reads SMS messages from the modem. Supports querying all messages or by specific types (e.g., "REC READ").

**Example Request**:

```bash
curl -X GET "http://localhost:8000/sms?msg_query=ALL"
```

**Response**:
```json
[
  {
    "message_index": "1",
    "message_type": "REC READ",
    "message_originating_address": "+1234567890",
    "message_date": "2024-09-17",
    "message_time": "22:48:47",
    "message_contents": "Hello World"
  }
]
```

#### Send SMS `POST /sms`

- **Method**: `POST`
- **Description**: Sends an SMS message to the specified phone number.

**Example Request**:

```bash
curl -X POST -H "Content-Type: application/json" \
-d '{"number":"+1234567890","msg":"Hello World"}' \
"http://localhost:8000/sms"
```

**Response**:
```json
{
  "response": true
}
```

#### Delete SMS `DELETE /sms/delete/{msg_idx}`

- **Method**: `DELETE`
- **Description**: Deletes an SMS by its message index.

**Example Request**:

```bash
curl -X DELETE http://localhost:8000/sms/delete/1
```

**Response**:
```json
{
  "response": "Success"
}
```

### AT Command Interface `/at`

- **Method**: `POST`
- **Description**: Sends raw AT commands to the modem and retrieves the response.

**Example Request**:

```bash
curl -X POST -H "Content-Type: application/json" \
-d '{"cmd":"AT+CSQ"}' \
"http://localhost:8000/at"
```

**Response**:
```json
"OK"
```

### API Documentation `/docs` and `/redoc`

FastAPI provides built-in interactive documentation to explore the API endpoints:

- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)

These pages allow you to explore and test the API directly from the browser.

## Resources

- [SIM7600G-H 4G HAT Product Page](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
- [SIM7600 AT Command Manual](https://www.waveshare.net/w/upload/6/68/SIM7500_SIM7600_Series_AT_Command_Manual_V2.00.pdf)

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request if you have suggestions or improvements.

## License

*License information will be added soon.*

---

*Note: This project is under active development, and documentation will be updated as features are added.*
