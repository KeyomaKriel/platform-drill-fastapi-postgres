# Automated Multi-App Drill Setup

Deploy any drill app (Flask, Django, Go) to a GitHub Codespace running k3d. Each app has full K8s manifests, Postgres, and nginx Ingress.

**Only one app can be deployed at a time** — all three Ingresses claim the `/` path, so you must delete the current namespace before deploying a different app.

---

## Available apps

| App | Framework | Domain | Namespace | Port | Health endpoint |
|-----|-----------|--------|-----------|------|-----------------|
| `drill-app` | Flask (Python) | Fleet tracking | `fleet-ops` | 7600 | `/api/v1/status` |
| `drill-app-django` | Django + DRF (Python) | Incident management | `incident-mgmt` | 8200 | `/api/v1/status` |
| `drill-app-go` | net/http (Go) | Warehouse inventory | `warehouse-sys` | 9090 | `/readyz` |

Each app has:
- Dockerfile
- K8s manifests (Namespace, ConfigMap, Secret, PVC, Deployment, Service, Ingress)
- Postgres 16 database with seed data
- Init container waiting for DB readiness
- Readiness and liveness probes
- `deploy.sh` that builds, loads into k3d, deploys, and verifies end-to-end

---

## Prerequisites

On your Mac:

```bash
# GitHub CLI (required)
brew install gh
gh auth login
```

---

## One-time setup

The repo includes a `.devcontainer/` that configures Codespaces with Docker, kubectl, helm, k3d, and an nginx Ingress controller. When a Codespace is created, `setup-cluster.sh` runs automatically and sets up the cluster.

### Create a Codespace

```bash
gh codespace create \
  -R KeyomaKriel/platform-drill-fastapi-postgres \
  -b mac-eks-drill \
  -m basicLinux32gb \
  --idle-timeout 30m \
  --default-permissions
```

Wait ~3 minutes for provisioning. Check state with:

```bash
gh codespace list -R KeyomaKriel/platform-drill-fastapi-postgres --json name,state
```

---

## Accessing the Codespace

**Browser (recommended for drills):**

```bash
gh codespace code -c <codespace-name> --web
```

Or go to https://github.com/codespaces and click the running Codespace.

The browser gives you a full VS Code editor with file explorer, multiple terminal tabs (one for commands, one for session logging), the K8s extension, and automatic port forwarding via the Ports tab. This is closest to what the interview environment will feel like.

**SSH (for quick commands or scripting):**

```bash
gh codespace ssh -c <codespace-name>
```

---

## Deploying an app

The repo is already cloned inside the Codespace at `/workspaces/platform-drill-fastapi-postgres/`. No need to copy files — just run the deploy script from the terminal.

### From the Codespace terminal (browser or SSH)

```bash
# Pick one:
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
# cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go
# cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app

bash deploy.sh
```

The deploy script builds the Docker image, loads it into k3d, applies all manifests, waits for rollouts, and verifies health end-to-end.

### From your Mac via SSH (non-interactive)

```bash
CS=<codespace-name>
gh codespace ssh -c "$CS" -- 'cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go && bash deploy.sh'
```

---

## Drill session workflow

### Start a drill

Open the Codespace in your browser, then in a terminal:

```bash
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
script -q -a ./session.log
```

If the app is **not yet deployed** (orientation drill), deploy it yourself as practice — that's the point. If it's **already deployed** (debugging drill), verify it's healthy, then inject a fault.

### Switching between apps

Only one app can run at a time. Delete the current namespace before deploying another:

```bash
# Tear down current app
kubectl delete namespace warehouse-sys   # or incident-mgmt or fleet-ops

# Deploy a different one
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
bash deploy.sh
```

### Retrieve session logs from your Mac

```bash
gh codespace ssh -c <codespace-name> -- 'cat /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/session.log' > session.log
```

---

## App-specific deploy details

### Flask (`drill-app`)

```
Image: fleet-tracker:local
Namespace: fleet-ops
DB: fleet_registry (user: fleet_admin)
Init: App seeds DB on startup (no init container for migrations)
Endpoints:
  GET  /api/v1/status     -> health check
  GET  /api/v1/vehicles   -> list vehicles
  GET  /api/v1/vehicles/1 -> single vehicle
  POST /api/v1/vehicles   -> create vehicle
```

### Django (`drill-app-django`)

```
Image: incident-api:local
Namespace: incident-mgmt
DB: incident_store (user: incident_admin)
Init: Two init containers:
  1. wait-for-db (busybox nc check)
  2. run-migrations (manage.py migrate + loaddata)
Endpoints:
  GET  /                       -> app info
  GET  /api/v1/status          -> health check (DB connectivity)
  GET  /api/v1/incidents       -> list incidents
  GET  /api/v1/incidents/1     -> single incident
  POST /api/v1/incidents/new   -> create incident
```

Key Django differences from Flask:
- Migrations run in an init container, not at app startup
- Two init containers (wait-for-db + run-migrations) vs one
- Uses `POSTGRES_*` env vars (not `PG*`)
- Project structure: `config/` (settings, urls, wsgi) + `incidents/` (app)
- Gunicorn command: `gunicorn config.wsgi:application`

### Go (`drill-app-go`)

```
Image: inventory-api:local
Namespace: warehouse-sys
DB: warehouse (user: inv_admin)
Init: App seeds DB on startup (like Flask)
Endpoints:
  GET  /                    -> app info
  GET  /healthz             -> liveness (no DB check)
  GET  /readyz              -> readiness (DB ping)
  GET  /api/v1/products     -> list products
  GET  /api/v1/products/1   -> single product
  POST /api/v1/products     -> create product
```

Key Go differences:
- Multi-stage Dockerfile (golang:1.22-alpine builder -> alpine:3.20 runtime)
- Final image is ~37MB vs ~297MB for Django
- Separate liveness (`/healthz`) and readiness (`/readyz`) endpoints
- Uses `DB_*` env vars (not `PG*` or `POSTGRES_*`)
- Lower resource requests (50m CPU, 32Mi memory)
- Runs as `nobody` user in container
- No migration tool — inline SQL at startup

---

## Structural comparison for orientation practice

| Aspect | Flask | Django | Go |
|--------|-------|--------|-----|
| Entry point | `src/app.py` | `manage.py` / `config/wsgi.py` | `main.go` |
| Config | env vars in code | `config/settings.py` | env vars in code |
| DB driver | psycopg2 | Django ORM + psycopg2 | pgx v5 |
| Server | gunicorn | gunicorn | built-in http.Server |
| Migrations | none (CREATE IF NOT EXISTS) | Django migrations + fixtures | none (CREATE IF NOT EXISTS) |
| Dockerfile | single stage | single stage | multi-stage |
| Init containers | 1 (wait-for-db) | 2 (wait-for-db + migrations) | 1 (wait-for-db) |
| DB env vars | PG* | POSTGRES_* | DB_* |
| Health check | `/api/v1/status` | `/api/v1/status` | `/healthz` + `/readyz` |

---

## Troubleshooting

### Codespace creation fails

```bash
# Check existing codespaces
gh codespace list
# Delete old ones to free up quota
gh codespace delete -c <name>
```

### Cluster not ready after Codespace creation

Open the Codespace and check:

```bash
k3d cluster list
kubectl get nodes
kubectl get pods -n ingress-nginx
```

If the cluster doesn't exist, run the setup manually:

```bash
bash /workspaces/platform-drill-fastapi-postgres/.devcontainer/setup-cluster.sh
```

### Image not found in k3d

After building, you must load the image into k3d:

```bash
k3d image import <image>:local -c drill-cluster
```

Verify with:

```bash
docker exec k3d-drill-cluster-server-0 crictl images | grep <image>
```

### Ingress not routing

```bash
kubectl get ingress -n <namespace>
kubectl get endpoints -n <namespace>
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
```

### Port 80 conflict between apps

Only one app's Ingress can claim `/` at a time. Delete the old namespace first:

```bash
kubectl delete namespace <old-namespace>
```

---

## Costs

GitHub free tier: 120 core-hours/month.

| Machine | Cores | Hours/month | Cost per hour |
|---------|-------|-------------|---------------|
| basicLinux32gb | 2 | 60h | 2 core-hours |
| standardLinux32gb | 4 | 30h | 4 core-hours |

A 2-core Codespace gives ~60 hours of drill time per month. Set `--idle-timeout 30m` to avoid wasting hours on idle Codespaces.

---

## Quick reference

```bash
# Create codespace
gh codespace create -R KeyomaKriel/platform-drill-fastapi-postgres -b mac-eks-drill -m basicLinux32gb --idle-timeout 30m --default-permissions

# Open in browser (recommended)
gh codespace code -c <codespace-name> --web

gh codespace code -c symmetrical-space-lamp-x5x4pg9wqjx626wxx --web

# Or SSH in
gh codespace ssh -c <codespace-name>

# Deploy an app (from inside the Codespace)
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go
bash deploy.sh

# Switch apps
kubectl delete namespace warehouse-sys
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
bash deploy.sh

# Start a drill session
script -q -a ./session.log

# Retrieve session log (from your Mac)
gh codespace ssh -c <codespace-name> -- 'cat /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go/session.log' > session.log

# Stop the codespace (saves core-hours)
gh codespace stop -c <codespace-name>

# Delete codespace
gh codespace delete -c <codespace-name>
```
