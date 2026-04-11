# Incident Response API

Internal incident tracking and management service.

## Development

Requires Python 3.12+ and a running PostgreSQL instance.

```bash
pip install -r requirements.txt
python manage.py migrate
python manage.py loaddata seed_incidents
python manage.py runserver 0.0.0.0:8200
```

## Deployment

Container image and Kubernetes manifests are in `manifests/`.

Build:

```bash
docker build -t incident-api:local .
```

## Environment variables

The application reads database connection settings from environment variables. See the Kubernetes manifests for the expected configuration.
