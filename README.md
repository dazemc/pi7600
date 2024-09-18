# Py_RPI_SIM: Python Library and REST API for SIM7600G-H 4G HAT

*Disclaimer: This README has been AI-generated as a quick and easy way to provide documentation during early development. Features are subject to change as the project evolves.*

[GitHub Repository](https://github.com/dazemc/py_rpi_sim)

## Overview

**Py_RPI_SIM** is a Python library and FastAPI-based REST API for managing the [SIM7600G-H 4G HAT from Waveshare](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B)) on a Raspberry Pi. The project enables various modem management operations, such as:

- Checking modem information and status
- Retrieving host device information
- Managing SMS messages (send, read, delete)
- Executing raw AT commands
- Accessing GPS data

This tool integrates modules like `GPS`, `Phone`, `SMS`, and `AT` to offer comprehensive modem control.

## Features

- **Modem Information and Status**: Check the network and modem status.
- **Host Device Information**: Retrieve system details (hostname, kernel version, date, and architecture).
- **SMS Management**: Send, read, and delete SMS messages.
- **AT Command Interface**: Execute raw AT commands and receive modem responses.
- **GPS Integration**: Access GPS data from the SIM7600 module.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [API Endpoints](#api-endpoints)
  - [Root `/`](#root-)
  - [Info `/info`](#info-info)
  - [SMS Management `/sms`](#sms-management-sms)
    - [Read Messages `GET /sms`](#read-messages-get-sms)
    - [Send Message `POST /sms`](#send-message-post-sms)
    - [Delete Message `GET /sms/delete/{msg_idx}`](#delete-message-get-smsdelete-msg_idx)
  - [AT Command Interface `/at`](#at-command-interface-at)
  - [API Documentation `/docs` and `/redoc`](#api-documentation-docs-and-redoc)
- [Resources and Notes](#resources-and-notes)
- [Contributing](#contributing)
- [License](#license)

## Installation

*Installation instructions will be added once the project reaches a stable state.*

## Usage

*Usage instructions will be updated as the project develops.*

## API Endpoints

### Root `/`

- **Method**: `GET`
- **Description**: Returns modem information and status.

**Example Request**:

```bash
curl -X GET http://localhost:8000/
```

**Response**:
```json
{
  "AT": "OK",
  "CSQ?": "OK",
  "CSPIN?": "OK",
  "CREG?": "OK",
  "COPS?": "OK",
  "GPS": "OK",
  "DATA": "OK",
  "DNS": "OK"
}
```

### Info `/info`

- **Method**: `GET`
- **Description**: Retrieves host device information like hostname, kernel version, and architecture.

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

#### Read Messages `GET /sms`

- **Method**: `GET`
- **Description**: Reads messages from the modem.

**Example Request**:

```bash
curl -X GET "http://localhost:8000/sms?msg_query=ALL"
```

**Response**:
```json
{
  "response": [
    {
      "message_index": "1",
      "message_type": "REC READ",
      "message_originating_address": "+1234567890",
      "message_date": "2024-09-17",
      "message_time": "22:48:47",
      "message_contents": "Hello World"
    }
  ]
}
```

#### Send Message `POST /sms`

- **Method**: `POST`
- **Description**: Sends an SMS to a specified phone number.

**Example Request**:

```bash
curl -X POST "http://localhost:8000/sms?msg=Hello%20World&number=+1234567890"
```

**Response**:
```json
{
  "response": true
}
```

#### Delete Message `GET /sms/delete/{msg_idx}`

- **Method**: `GET`
- **Description**: Deletes an SMS message by its index.

**Example Request**:

```bash
curl -X GET http://localhost:8000/sms/delete/1
```

**Response**:
```json
{
  "response": "Success"
}
```

### AT Command Interface `/at`

- **Method**: `POST`
- **Description**: Sends raw AT commands to the modem.

**Example Request**:

```bash
curl -X POST "http://localhost:8000/at?cmd=AT+CSQ"
```

**Response**:
```json
"OK"
```

### API Documentation `/docs` and `/redoc`

FastAPI provides built-in interactive documentation to explore the API endpoints:

- **Swagger UI** (interactive API docs): [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc** (alternative API docs): [http://localhost:8000/redoc](http://localhost:8000/redoc)

These pages allow you to explore and test the API directly from the browser.

## Resources and Notes

- [SIM7600G-H 4G HAT Product Page](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
- [SIM7600 AT Command Manual](https://www.waveshare.net/w/upload/6/68/SIM7500_SIM7600_Series_AT_Command_Manual_V2.00.pdf)
- [SIM7X00 TCPIP Application Note](https://www.waveshare.com/w/upload/7/79/SIM7X00_Series_TCPIP_Application_Note_V1.00.pdf)

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any changes or suggestions.

## License

*License information will be added later.*

---

*Note: This project is under active development, and features may change frequently. The documentation will be updated accordingly.*
