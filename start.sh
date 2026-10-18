#!/bin/bash

LOG_DIR=".log"
LOG_PATH="${LOG_DIR}/uvicorn.log"

if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

if [ -f "$LOG_PATH" ]; then
    mv "$LOG_PATH" "${LOG_PATH}_old"
fi

touch "$LOG_PATH"

uvicorn main:app --host 0.0.0.0 --log-config log.yaml

