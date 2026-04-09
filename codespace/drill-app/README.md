# Fleet Tracker API

Internal vehicle fleet management service.

## Development

Requires Python 3.12+ and a running PostgreSQL instance.

```bash
pip install -r src/requirements.txt
python src/app.py
```

## Deployment

Container image and Kubernetes manifests are in `manifests/`.

Build:

```bash
docker build -t fleet-tracker:local .
```

## Environment variables

The application reads database connection settings from environment variables. See the Kubernetes manifests for the expected configuration.
