FROM python:3.12-slim

WORKDIR /opt/incident-api

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY config ./config
COPY incidents ./incidents
COPY manage.py .

EXPOSE 8200

CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8200", "--workers", "2"]
