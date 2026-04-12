# Repo Orientation — drill-app-go Answer Key

## Phase 1: Scan

```
drill-app-go/
├── Dockerfile
├── .dockerignore
├── README.md
├── deploy.sh
├── go.mod
├── main.go
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

> "I can see a single Go source file at the root, a Dockerfile, a deploy script, and Kubernetes manifests in `manifests/`. This is a single-service app with a database. No Helm, no Kustomize — raw manifests. There's a deploy.sh which probably automates the build-and-deploy path."

---

## Phase 2: Key file extractions

### Dockerfile

- **Multi-stage build:** `golang:1.22-alpine` (builder) → `alpine:3.20` (runtime)
- **Build:** copies `go.mod` and `*.go`, runs `go mod tidy` then builds a static binary (`CGO_ENABLED=0`)
- **Process:** `CMD ["./inventory-api"]` — runs the compiled binary directly
- **Port:** EXPOSE 9090
- **User:** runs as `nobody:nobody` (non-root)

> "This is a Go app with a multi-stage build. The final image is minimal Alpine running a static binary on port 9090 as non-root."

### main.go

- **Framework:** Go stdlib `net/http` with `pgx/v5` for Postgres
- **Endpoints:**
  - `GET /` — returns app name (`inventory-api`), version (`0.1.0`), hostname
  - `GET /healthz` — liveness check, always returns 200 `{"status": "alive"}`
  - `GET /readyz` — readiness check, pings DB with 2s timeout, returns 200 or 503
  - `GET /api/v1/products` — lists all products from the `products` table
  - `GET /api/v1/products/{id}` — get single product by ID
  - `POST /api/v1/products` — create a new product
- **DB connection env vars:** `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- **Listen port env var:** `LISTEN_PORT` (defaults to `9090`)
- **Startup:** connects to Postgres via connection pool (`pgxpool`), pings to verify, creates `products` table, seeds 3 rows if empty. If DB is unreachable at startup, `log.Fatalf` — crashes (no retry).
- **Shutdown:** graceful shutdown on SIGINT/SIGTERM with 10s timeout
- **Key detail:** liveness (`/healthz`) and readiness (`/readyz`) are separate — liveness doesn't check DB, readiness does. This means a DB outage after startup will fail readiness but not kill the pod via liveness.

> "This is a Go stdlib API with 6 endpoints. It connects to Postgres using 5 env vars. On startup it creates a table and seeds data — crashes if DB is unreachable. Liveness and readiness are split: liveness always passes, readiness checks DB. Graceful shutdown on SIGTERM."

### manifests/api-deployment.yaml

- **Image:** `inventory-api:local`, `imagePullPolicy: Never` (local image)
- **Replicas:** 2
- **Labels:** `component: api`
- **Init container:** busybox, waits for `inventory-db-svc:5432` with `nc -z`
- **envFrom:** ConfigMap `inventory-api-config` + Secret `inventory-api-credentials`
- **Probes:**
  - Readiness: `GET /readyz` on port 9090, initial delay 3s, period 10s
  - Liveness: `GET /healthz` on port 9090, initial delay 5s, period 30s
- **Resources:** 50m/32Mi requests, 200m/64Mi limits

> "The Deployment runs 2 replicas of `inventory-api:local` with an init container that waits for the DB. Config comes from a ConfigMap and a Secret. Readiness probes hit `/readyz` (checks DB), liveness probes hit `/healthz` (always alive). Small resource footprint — Go binary."

### manifests/api-configmap.yaml + api-secret.yaml

- **ConfigMap `inventory-api-config`:** DB_HOST=`inventory-db-svc`, DB_PORT=`5432`, DB_NAME=`warehouse`, LISTEN_PORT=`9090`
- **Secret `inventory-api-credentials`:** DB_USER=`inv_admin`, DB_PASSWORD=`Tj7!cQx3mR`
- **Cross-reference:** App reads `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` — all provided. DB_HOST points to `inventory-db-svc` which should be the DB Service name.

> "Config and creds are split across a ConfigMap and Secret. DB host points to `inventory-db-svc`. All env vars the app expects are provided."

### manifests/api-service.yaml

- **Name:** `inventory-api-svc`
- **Selector:** `component: api` — matches Deployment pod labels
- **Port:** 80 → targetPort 9090
- **Type:** ClusterIP (default)

> "Service selects `component: api` pods, maps port 80 to targetPort 9090. That matches the container's listening port."

### manifests/ingress.yaml

- **Name:** `inventory-api-ingress`
- **IngressClassName:** nginx
- **Rule:** path `/` → service `inventory-api-svc` port 80
- **Annotation:** `rewrite-target: /`

> "Ingress routes all traffic on `/` to `inventory-api-svc` on port 80. That matches the Service name and port."

### manifests/db-deployment.yaml + db-service.yaml + db-configmap.yaml + db-secret.yaml + db-pvc.yaml

- **Image:** postgres:16-alpine
- **envFrom:** ConfigMap `inventory-db-config` (POSTGRES_DB=`warehouse`) + Secret `inventory-db-credentials` (POSTGRES_USER=`inv_admin`, POSTGRES_PASSWORD=`Tj7!cQx3mR`)
- **Labels:** `component: database`
- **Service name:** `inventory-db-svc` — this is what the app's DB_HOST points to
- **Service selector:** `component: database` — matches DB pod labels
- **Service port:** 5432 → 5432
- **PVC:** `inventory-db-storage`, 512Mi, ReadWriteOnce
- **Volume mount:** `/var/lib/postgresql/data` with subPath `pgdata`
- **Probes:** readiness and liveness via `pg_isready -U inv_admin -d warehouse`
- **Cross-reference:** DB creds (`inv_admin` / `Tj7!cQx3mR`) match the app's Secret. DB name `warehouse` matches the app's ConfigMap. Service name `inventory-db-svc` matches the app's DB_HOST.

> "Postgres runs as `postgres:16-alpine` with a PVC for persistence. Service name is `inventory-db-svc` — matches what the app config expects. Creds and DB name match across both sides."

### manifests/namespace.yaml

- **Namespace:** `warehouse-sys`

### deploy.sh

- Builds Docker image, imports into k3d, applies manifests, waits for rollouts, runs health checks
- Uses `K3D_CLUSTER` env var (defaults to `drill-cluster`)
- Verifies with curl to `/`, `/readyz`, `/api/v1/products`

> "There's a deploy script that automates the full build-load-deploy-verify path. Useful reference for the expected deploy flow."

---

## Phase 3: Summary narration

> **Shape:** "This is a Go stdlib API with 6 endpoints for warehouse inventory tracking, backed by Postgres, deployed via raw K8s manifests into the `warehouse-sys` namespace."
>
> **Start:** "Containerized with Docker — multi-stage build produces a static binary running on port 9090. On startup it connects to Postgres, creates a `products` table, and seeds 3 rows. If the DB isn't reachable, it crashes — no retry. There's an init container that waits for the DB service before the app starts. Graceful shutdown on SIGTERM."
>
> **Supply:** "The app needs 5 env vars for Postgres — DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, plus LISTEN_PORT. These come from ConfigMap `inventory-api-config` and Secret `inventory-api-credentials`. DB host points to service `inventory-db-svc`. Creds and DB name match between the app config and the Postgres config."
>
> **Ship:** "Deployment runs 2 replicas with readiness probes on `/readyz:9090` (checks DB) and liveness probes on `/healthz:9090` (always passes). Service maps port 80 to targetPort 9090. Ingress routes `/` to the service on port 80 via nginx. Labels and selectors match throughout."
>
> **Signals:** "If the DB is down at startup, the app crashes — I'd see CrashLoopBackOff and connection errors in logs. If the DB goes down after startup, readiness fails but liveness still passes — pods stay Running but become not Ready, endpoints empty. If the Service selector is wrong, endpoints empty but pods Running. If Ingress is wrong, direct pod curl works but `curl localhost/` doesn't."

---

## Connection chain

```
App reads DB_HOST env var
  → inventory-api-config ConfigMap: DB_HOST = inventory-db-svc
    → inventory-db-svc Service selector: component=database
      → DB pod labels: component=database ✓
        → DB pod running postgres:16-alpine on port 5432

App listens on port 9090 (Go http.Server)
  → Deployment containerPort: 9090
    → inventory-api-svc targetPort: 9090, port: 80
      → Ingress backend: inventory-api-svc port 80
        → curl localhost/ works
```

---

## Deploy path

```bash
# Build and load image
docker build -t inventory-api:local .
k3d image import inventory-api:local -c <cluster-name>

# Ingress controller — check if one is running first
kubectl get pods -n ingress-nginx
# If no controller is running:
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

# Deploy
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/

# Or just use the deploy script:
# bash deploy.sh

# Verify
kubectl get pods -n warehouse-sys
kubectl get endpoints -n warehouse-sys
curl localhost/readyz
curl localhost/api/v1/products
```

---

## Key differences from drill-app (Flask)

| | drill-app (Flask) | drill-app-go (Go) |
|---|---|---|
| Language | Python / Flask | Go / stdlib |
| DB library | psycopg2 | pgx/v5 (connection pool) |
| DB env vars | PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD | DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD |
| Health endpoint | `/api/v1/status` (single, checks DB) | `/healthz` (liveness, no DB) + `/readyz` (readiness, checks DB) |
| Listen port | 7600 (gunicorn) | 9090 (Go http.Server) |
| Namespace | fleet-ops | warehouse-sys |
| Shutdown | gunicorn handles it | Explicit graceful shutdown (SIGTERM) |
| Deploy script | None | `deploy.sh` included |
| Docker build | Single stage | Multi-stage (builder + runtime) |
