#!/bin/bash
uvicorn main:app --host 0.0.0.0 --log-config .log.yaml --reload --reload-exclude __pycache__