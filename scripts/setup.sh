#!/bin/bash
# ModemManager can claim the SIM7600 serial ports. Disabling it lets the
# application open /dev/ttyUSB2 directly. Review the change before running.
set -euo pipefail

sudo systemctl disable ModemManager
