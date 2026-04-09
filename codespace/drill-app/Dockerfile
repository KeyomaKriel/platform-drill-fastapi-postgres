FROM python:3.12-slim

WORKDIR /opt/fleet

COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ .

EXPOSE 7600

CMD ["gunicorn", "--bind", "0.0.0.0:7600", "--workers", "2", "app:app"]
