import os
import socket

from fastapi import FastAPI

app = FastAPI(title="Platform Drill API")

APP_VERSION = os.getenv("APP_VERSION", "dev")
HOSTNAME = socket.gethostname()


@app.get("/")
def root():
    return {
        "app": "platform-drill-api",
        "version": APP_VERSION,
        "hostname": HOSTNAME,
        "message": "API is running"
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": APP_VERSION
    }


@app.get("/items")
def items():
    return {
        "source": "in-memory",
        "items": [
            {"id": 1, "name": "keyboard"},
            {"id": 2, "name": "monitor"}
        ]
    }
