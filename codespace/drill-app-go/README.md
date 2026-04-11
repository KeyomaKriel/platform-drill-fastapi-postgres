# Inventory API

Warehouse inventory tracking service.

## Development

Requires Go 1.22+ and a running PostgreSQL instance.

```bash
export DB_HOST=localhost DB_PORT=5432 DB_NAME=warehouse DB_USER=inv_admin DB_PASSWORD=localdev
go run .
```

## Deployment

Container image and Kubernetes manifests are in `manifests/`.

Build:

```bash
docker build -t inventory-api:local .
```

## Environment variables

The application reads database connection settings from environment variables. See the Kubernetes manifests for the expected configuration.
