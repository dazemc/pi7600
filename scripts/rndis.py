#!/usr/bin/env python3
"""Switch the modem USB personality to the UNIX/RNDIS setting."""

import asyncio
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
os.chdir(ROOT)

from pi7600 import Settings  # noqa: E402


async def main() -> None:
    settings = Settings()
    await settings.initialize()
    await settings.set_usb_os("UNIX")


if __name__ == "__main__":
    asyncio.run(main())
