# Drill 01 — Orientation Answer Key

## Phase 1: Scan

```
drill-app/
├── Dockerfile
├── .dockerignore
├── README.md
├── src/
│   ├── app.py
│   └── requirements.txt
└── manifests/
    ├── namespace.yaml
    ├── db-configmap.yaml
    ├── db-secret.yaml
    ├── db-pvc.yaml
    ├── db-deployment.yaml
    ├── db-service.yaml
    ├── tracker-configmap.yaml
    ├── tracker-secret.yaml
    ├── tracker-deployment.yaml
    ├── tracker-service.yaml
    └── ingress.yaml
```

> "I can see app code in `src/`, a Dockerfile at the root, and Kubernetes manifests in `manifests/`. This is a single-service app with a database. No Helm, no docker-compose for K8s — raw manifests."

---

## Phase 2: Key file extractions

### Dockerfile

- **Base image:** python:3.12-slim
- **Process:** gunicorn on port 7600, 2 workers
- **App module:** `app:app` — so `src/app.py` is the main file

> "The container runs gunicorn on port 7600."

### src/app.py

- **Framework:** Flask
- **Endpoints:**
  - `GET /api/v1/status` — health check, tests DB connection, returns 200 or 503
  - `GET /api/v1/vehicles` — lists all vehicles from the `vehicles` table
  - `GET /api/v1/vehicles/<id>` — get single vehicle by ID
  - `POST /api/v1/vehicles` — create a new vehicle
- **DB connection env vars:** `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
- **Startup:** `init_db()` runs on `__main__` — creates the `vehicles` table and seeds 3 rows if empty
- **Startup dependency:** if Postgres is unreachable at startup, the app crashes (no retry)

> "This is a Flask app with 4 endpoints. It reads Postgres connection details from env vars. On startup it creates a table and seeds data. If the DB is down, it crashes."

### manifests/tracker-deployment.yaml

- **Image:** `fleet-tracker:local`, `imagePullPolicy: Never` (local image, not pulled from registry)
- **Replicas:** 2
- **Labels:** `component: api`
- **Init container:** busybox, waits for `fleet-db-svc:5432` with `nc -z`
- **envFrom:** ConfigMap `tracker-settings` + Secret `tracker-db-auth`
- **Probes:**
  - Readiness: `GET /api/v1/status` on port 7600, initial delay 5s, period 10s
  - Liveness: `GET /api/v1/status` on port 7600, initial delay 10s, period 30s
- **Resources:** 100m/128Mi requests, 250m/256Mi limits

> "The Deployment runs 2 replicas of `fleet-tracker:local` with an init container that waits for the DB. Config comes from a ConfigMap and a Secret. Probes hit `/api/v1/status` on port 7600."

### manifests/tracker-configmap.yaml + tracker-secret.yaml

- **ConfigMap `tracker-settings`:** PGHOST=`fleet-db-svc`, PGPORT=`5432`, PGDATABASE=`fleet_registry`, LISTEN_PORT=`7600`
- **Secret `tracker-db-auth`:** PGUSER=`fleet_admin`, PGPASSWORD=`Xr9!mKq2vL`
- **Cross-reference:** App reads `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD` — all provided. PGHOST points to `fleet-db-svc` which should be the DB Service name.

> "Config and creds are split across a ConfigMap and Secret. DB host points to `fleet-db-svc`. All env vars the app expects are provided."

### manifests/tracker-service.yaml

- **Selector:** `component: api` — matches Deployment pod labels
- **Port:** 80 → targetPort 7600
- **Type:** ClusterIP (default)

> "Service selects `component: api` pods, maps port 80 to targetPort 7600. That matches the container's listening port."

### manifests/ingress.yaml

- **IngressClassName:** nginx
- **Rule:** path `/` → service `tracker-svc` port 80
- **Annotation:** `rewrite-target: /`

> "Ingress routes all traffic on `/` to `tracker-svc` on port 80. That matches the Service name and port."

### manifests/db-deployment.yaml + db-service.yaml + db-configmap.yaml + db-secret.yaml + db-pvc.yaml

- **Image:** postgres:16-alpine
- **envFrom:** ConfigMap `fleet-db-config` (POSTGRES_DB=`fleet_registry`, PGPORT=`5432`) + Secret `fleet-db-credentials` (POSTGRES_USER=`fleet_admin`, POSTGRES_PASSWORD=`Xr9!mKq2vL`)
- **Labels:** `component: database`
- **Service name:** `fleet-db-svc` — this is what the app's PGHOST points to
- **Service selector:** `component: database` — matches DB pod labels
- **Service port:** 5432 → 5432
- **PVC:** `fleet-db-storage`, 512Mi, ReadWriteOnce
- **Volume mount:** `/var/lib/postgresql/data` with subPath `pgdata`
- **Probes:** readiness and liveness via `pg_isready -U fleet_admin -d fleet_registry`
- **Cross-reference:** DB creds (`fleet_admin` / `Xr9!mKq2vL`) match the app's Secret. DB name `fleet_registry` matches the app's ConfigMap. Service name `fleet-db-svc` matches the app's PGHOST.

> "Postgres runs as `postgres:16-alpine` with a PVC for persistence. Service name is `fleet-db-svc` — matches what the app config expects. Creds and DB name match across both sides."

### manifests/namespace.yaml

- **Namespace:** `fleet-ops`

---

## Phase 3: Summary narration

> **Shape:** "This is a Flask API with 4 endpoints for vehicle fleet management, backed by Postgres, deployed via raw K8s manifests into the `fleet-ops` namespace."
>
> **Start:** "It's containerized with Docker — runs gunicorn on port 7600. On startup it connects to Postgres, creates a `vehicles` table, and seeds 3 rows. If the DB isn't reachable, it crashes — no retry. There's an init container that waits for the DB service before the app starts."
>
> **Supply:** "The app needs 5 env vars for Postgres — host, port, database, user, password. These come from ConfigMap `tracker-settings` and Secret `tracker-db-auth`. DB host points to the service `fleet-db-svc`. Creds and DB name match between the app config and the Postgres config."
>
> **Ship:** "Deployment runs 2 replicas with readiness and liveness probes on `/api/v1/status:7600`. Service maps port 80 to targetPort 7600. Ingress routes `/` to the service on port 80 via nginx. Labels and selectors match throughout."
>
> **Signals:** "If the DB is down, the app crashes on startup — I'd see CrashLoopBackOff and connection errors in logs. If probes fail, endpoints would be empty. If the Service selector is wrong, endpoints would be empty but pods would be Running. If Ingress is wrong, direct pod curl would work but `curl localhost/` wouldn't."

---

## Connection chain

```
App reads PGHOST env var
  → tracker-settings ConfigMap: PGHOST = fleet-db-svc
    → fleet-db-svc Service selector: component=database
      → DB pod labels: component=database ✓
        → DB pod running postgres:16-alpine on port 5432

App listens on port 7600 (gunicorn)
  → Deployment containerPort: 7600
    → tracker-svc targetPort: 7600, port: 80
      → Ingress backend: tracker-svc port 80
        → curl localhost/ works
```

---

## Deploy path

```bash
# Build and load image
docker build -t fleet-tracker:local .
k3d image import fleet-tracker:local -c <cluster-name>

# Ingress controller — the manifests require nginx, check if one is running first
kubectl get pods -n ingress-nginx
# If no controller is running:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Deploy
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/

# If port 80 isn't mapped to the host (common in pre-configured Codespaces),
# use port-forward to reach the ingress controller:
kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8080:80 &

# Verify
kubectl get pods -n fleet-ops
kubectl get endpoints -n fleet-ops
curl localhost:8080/api/v1/status
curl localhost:8080/api/v1/vehicles
```