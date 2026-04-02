import os
import socket

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.db import db_is_ok, fetch_items, init_db

app = FastAPI()


@app.on_event("startup")
def startup():
    init_db()


@app.get("/")
def read_root():
    return {
        "app": "platform-drill-api",
        "version": "dev",
        "hostname": socket.gethostname(),
        "message": "API is running",
    }


@app.get("/health")
def health():
    if not db_is_ok():
        return JSONResponse(
            status_code=503,
            content={
                "status": "error",
                "version": "dev",
                "database": "unreachable",
            },
        )

    return {
        "status": "ok",
        "version": "dev",
    }


@app.get("/items")
def read_items():
    return {
        "source": "postgres",
        "items": fetch_items(),
    }