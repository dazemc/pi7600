#!/bin/bash
LOG_PATH="/var/log/pi7600/uvicorn.log"
if [ -f "$LOG_PATH" ]; then
    mv "$LOG_PATH" "${LOG_PATH}_old"
fi
touch "$LOG_PATH"
uvicorn main:app --host 0.0.0.0 --log-config log.yaml --reload