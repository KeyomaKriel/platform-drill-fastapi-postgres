# Repo Orientation — drill-app-django Answer Key

## Phase 1: Scan

```
drill-app-django/
├── Dockerfile
├── .dockerignore
├── README.md
├── deploy.sh
├── manage.py
├── requirements.txt
├── config/
│   ├── __init__.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── incidents/
│   ├── __init__.py
│   ├── apps.py
│   ├── models.py
│   ├── serializers.py
│   ├── urls.py
│   ├── views.py
│   ├── migrations/
│   │   ├── __init__.py
│   │   └── 0001_initial.py
│   └── fixtures/
│       └── seed_incidents.json
└── manifests/
    ├── namespace.yaml
    ├── api-configmap.yaml
    ├── api-secret.yaml
    ├── api-deployment.yaml
    ├── api-service.yaml
    ├── db-configmap.yaml
    ├── db-secret.yaml
    ├── db-pvc.yaml
    ├── db-deployment.yaml
    ├── db-service.yaml
    └── ingress.yaml
```

> "This is a Django project — I can tell from `manage.py`, the `config/` project package, and the `incidents/` app package with models, views, serializers, and migrations. There's a Dockerfile, raw K8s manifests in `manifests/`, and a deploy script. The `fixtures/` directory suggests seed data loaded via Django's `loaddata` command."

---

## Phase 2: Key file extractions

### Dockerfile

- **Base image:** `python:3.12-slim`
- **Single-stage build** — installs deps from `requirements.txt`, copies `config/`, `incidents/`, and `manage.py`
- **Process:** `gunicorn config.wsgi:application --bind 0.0.0.0:8200 --workers 2`
- **Port:** EXPOSE 8200
- **WSGI module path:** `config.wsgi:application` — the WSGI app is in `config/wsgi.py`

> "This is a Django app served by gunicorn on port 8200. Single-stage build on python:3.12-slim. The WSGI entry point is `config.wsgi:application`."

### requirements.txt

- `django==5.1.7`, `djangorestframework==3.15.2`, `gunicorn==23.0.0`, `psycopg2-binary==2.9.10`

> "Django 5.1 with DRF for the API layer, psycopg2 for Postgres, gunicorn as the WSGI server."

### config/settings.py

- **DB engine:** `django.db.backends.postgresql`
- **DB env vars:** `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — all read from `os.environ.get()` with defaults
- **ALLOWED_HOSTS:** `["*"]` — accepts all hosts
- **INSTALLED_APPS:** `rest_framework`, `incidents`
- **REST_FRAMEWORK:** JSON renderer only, no auth
- **WSGI:** `config.wsgi.application`
- **Key detail:** Unlike Flask/Go apps that manage their own DB connection, Django uses the ORM. DB connection config lives in `settings.py`, not the view code.

> "Django reads Postgres config from 5 env vars — POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD. The database engine is `django.db.backends.postgresql` using psycopg2. DRF is configured for JSON-only responses."

### incidents/models.py

- **Model:** `Incident` with fields: `title` (CharField), `severity` (choices: critical/high/medium/low), `status` (choices: open/investigating/resolved/closed), `reporter` (CharField), `created_at` (DateTimeField, auto_now_add)
- **Ordering:** newest first (`-created_at`)

> "One model — Incident — with 5 fields. Ordered by most recent first."

### incidents/views.py + urls.py

- **Endpoints:**
  - `GET /` — returns app name (`incident-api`), version (`0.1.0`), hostname
  - `GET /api/v1/status` — health check, runs `SELECT 1` on the DB connection, returns 200 or 503
  - `GET /api/v1/incidents` — lists all incidents via DRF serializer
  - `GET /api/v1/incidents/<id>` — single incident by ID, 404 if not found
  - `POST /api/v1/incidents/new` — create incident, validates via serializer
- **Health check:** Uses `django.db.connection.cursor()` — tests the actual DB connection, not just the pool
- **Key detail:** The health endpoint is `/api/v1/status` (same path as the Flask app), not `/healthz` or `/readyz` like the Go app

> "Five endpoints — root info, health check, list incidents, get single incident, create incident. Health check runs a DB query and returns 503 if Postgres is unreachable. Uses DRF function-based views with serializers."

### manifests/api-deployment.yaml

- **Image:** `incident-api:local`, `imagePullPolicy: Never`
- **Replicas:** 2
- **Labels:** `component: api`
- **Two init containers:**
  1. `wait-for-db` — busybox, waits for `incident-db-svc:5432` with `nc -z` (hardcoded hostname)
  2. `run-migrations` — uses the app image, runs `python manage.py migrate --noinput && python manage.py loaddata seed_incidents`. Reads env from the same ConfigMap/Secret as the main container.
- **envFrom:** ConfigMap `incident-api-config` + Secret `incident-api-credentials`
- **Probes:**
  - Readiness: `GET /api/v1/status` on port 8200, initial delay 5s, period 10s
  - Liveness: `GET /api/v1/status` on port 8200, initial delay 10s, period 30s
- **Resources:** 100m/128Mi requests, 250m/256Mi limits
- **Key detail:** Two init containers is a Django-specific pattern. The first waits for DB connectivity, the second runs `manage.py migrate` and `loaddata` to set up the schema and seed data. Both must complete before the main container starts. The migration init container uses the app image with a custom command override, and reads the same env vars as the main container.

> "Two init containers — one waits for DB, the other runs Django migrations and loads fixture data. This is unique to Django — Flask/Go apps seed at startup in the main process. If either init container fails, the main container never starts. The migration init container reads from the same ConfigMap/Secret as the app."

### manifests/api-configmap.yaml + api-secret.yaml

- **ConfigMap `incident-api-config`:** POSTGRES_HOST=`incident-db-svc`, POSTGRES_PORT=`5432`, POSTGRES_DB=`incident_store`, LISTEN_PORT=`8200`
- **Secret `incident-api-credentials`:** POSTGRES_USER=`incident_admin`, POSTGRES_PASSWORD=`Wk4!pNz8rQ`
- **Cross-reference:** App reads `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` — all provided. POSTGRES_HOST points to `incident-db-svc` which should be the DB Service name.

> "Config and creds split across a ConfigMap and Secret. DB host points to `incident-db-svc`. All env vars the settings.py expects are provided."

### manifests/api-service.yaml

- **Name:** `incident-api-svc`
- **Selector:** `component: api` — matches Deployment pod labels
- **Port:** 80 → targetPort 8200
- **Type:** ClusterIP (default)

> "Service selects `component: api` pods, maps port 80 to targetPort 8200. That matches the container's listening port."

### manifests/ingress.yaml

- **Name:** `incident-api-ingress`
- **IngressClassName:** nginx
- **Rule:** path `/` → service `incident-api-svc` port 80
- **Annotation:** `rewrite-target: /`

> "Ingress routes all traffic on `/` to `incident-api-svc` on port 80. That matches the Service name and port."

### manifests/db-deployment.yaml + db-service.yaml + db-configmap.yaml + db-secret.yaml + db-pvc.yaml

- **Image:** postgres:16-alpine
- **envFrom:** ConfigMap `incident-db-config` (POSTGRES_DB=`incident_store`) + Secret `incident-db-credentials` (POSTGRES_USER=`incident_admin`, POSTGRES_PASSWORD=`Wk4!pNz8rQ`)
- **Labels:** `component: database`
- **Service name:** `incident-db-svc` — this is what the app's POSTGRES_HOST points to
- **Service selector:** `component: database` — matches DB pod labels
- **Service port:** 5432 → 5432
- **PVC:** `incident-db-storage`, 512Mi, ReadWriteOnce
- **Volume mount:** `/var/lib/postgresql/data` with subPath `pgdata`
- **Probes:** readiness and liveness via `pg_isready -U incident_admin -d incident_store`
- **Cross-reference:** DB creds (`incident_admin` / `Wk4!pNz8rQ`) match the app's Secret. DB name `incident_store` matches the app's ConfigMap. Service name `incident-db-svc` matches the app's POSTGRES_HOST.

> "Postgres runs as `postgres:16-alpine` with a PVC for persistence. Service name is `incident-db-svc` — matches what the app config expects. Creds and DB name match across both sides."

### manifests/namespace.yaml

- **Namespace:** `incident-mgmt`

### deploy.sh

- Builds Docker image, imports into k3d, applies manifests, waits for rollouts, runs health checks
- Uses `K3D_CLUSTER` env var (defaults to `drill-cluster`)
- Verifies with curl to `/`, `/api/v1/status`, `/api/v1/incidents`

---

## Phase 3: Summary narration

> **Shape:** "This is a Django + DRF API with 5 endpoints for incident tracking and management, backed by Postgres, deployed via raw K8s manifests into the `incident-mgmt` namespace."
>
> **Start:** "Containerized with Docker — single-stage build on `python:3.12-slim`, runs gunicorn on port 8200. Two init containers: one waits for DB connectivity with `nc`, the other runs `manage.py migrate` and loads seed data via `loaddata`. If the DB isn't reachable, the wait-for-db init container loops and the migration init container crashes. The main container never starts until both init containers succeed."
>
> **Supply:** "The app needs 5 env vars for Postgres — POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, plus LISTEN_PORT. These come from ConfigMap `incident-api-config` and Secret `incident-api-credentials`. DB host points to service `incident-db-svc`. Creds and DB name match between the app config and the Postgres config. The migration init container reads from the same ConfigMap/Secret."
>
> **Ship:** "Deployment runs 2 replicas with readiness and liveness probes both on `/api/v1/status:8200` (both check DB). Service maps port 80 to targetPort 8200. Ingress routes `/` to the service on port 80 via nginx. Labels and selectors match throughout."
>
> **Signals:** "If the DB is down, both probes fail (they both check DB) — pods become not Ready, endpoints empty, readiness probe returns 503. If the DB is down at startup, the migration init container crashes and the pod is stuck at `Init:1/2`. If probes are misconfigured, pods would be Running but not Ready. If the Service selector is wrong, endpoints empty but pods Running. If Ingress is wrong, direct pod curl works but `curl localhost/` doesn't."

---

## Connection chain

```
App reads POSTGRES_HOST env var
  → incident-api-config ConfigMap: POSTGRES_HOST = incident-db-svc
    → incident-db-svc Service selector: component=database
      → DB pod labels: component=database ✓
        → DB pod running postgres:16-alpine on port 5432

App listens on port 8200 (gunicorn)
  → Deployment containerPort: 8200
    → incident-api-svc targetPort: 8200, port: 80
      → Ingress backend: incident-api-svc port 80
        → curl localhost/ works

Init container chain:
  1. wait-for-db: nc -z incident-db-svc 5432 (hardcoded)
  2. run-migrations: manage.py migrate + loaddata (reads POSTGRES_* from ConfigMap/Secret)
  3. Main container: gunicorn starts
```

---

## Deploy path

```bash
# Build and load image
docker build -t incident-api:local .
k3d image import incident-api:local -c <cluster-name>

# Deploy
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/

# Or just use the deploy script:
# bash deploy.sh

# Verify
kubectl get pods -n incident-mgmt
kubectl get endpoints -n incident-mgmt
curl localhost/api/v1/status
curl localhost/api/v1/incidents
```

---

## Key differences from other drill apps

| | drill-app (Flask) | drill-app-django (Django) | drill-app-go (Go) |
|---|---|---|---|
| Language | Python / Flask | Python / Django + DRF | Go / stdlib |
| DB library | psycopg2 (raw SQL) | Django ORM + psycopg2 | pgx/v5 (connection pool) |
| DB env vars | PG* | POSTGRES_* | DB_* |
| DB config location | app.py `get_db_conn()` | config/settings.py `DATABASES` | main.go `connectDB()` |
| Migrations | None (CREATE IF NOT EXISTS) | Django migrations + fixtures (init container) | None (CREATE IF NOT EXISTS) |
| Health endpoint | `/api/v1/status` (checks DB) | `/api/v1/status` (checks DB) | `/healthz` (no DB) + `/readyz` (checks DB) |
| Probes | Both hit `/api/v1/status` | Both hit `/api/v1/status` | Liveness `/healthz`, Readiness `/readyz` |
| Init containers | 1 (wait-for-db) | 2 (wait-for-db + run-migrations) | 1 (wait-for-db) |
| Listen port | 7600 | 8200 | 9090 |
| Server | gunicorn | gunicorn | built-in http.Server |
| Namespace | fleet-ops | incident-mgmt | warehouse-sys |
| Dockerfile | Single stage | Single stage | Multi-stage |
| Project structure | Flat (src/app.py) | Django convention (config/ + incidents/) | Flat (main.go) |
| WSGI entry point | `app:app` | `config.wsgi:application` | N/A (compiled binary) |
