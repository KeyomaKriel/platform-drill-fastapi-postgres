# Automated Multi-App Drill Setup

Deploy any drill app (Flask, Django, Go) to a GitHub Codespace with a single command. Each app runs on k3d with full K8s manifests, Postgres, and nginx Ingress.

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
- `deploy.sh` that builds, loads, deploys, and verifies

---

## Prerequisites

On your Mac:

```bash
# GitHub CLI (required)
brew install gh
gh auth login

# Docker Desktop (required for local builds/verification)
# Download from https://www.docker.com/products/docker-desktop/
```

---

## One-time repo setup

The repo already includes a `.devcontainer/` that configures Codespaces with Docker, kubectl, helm, and k3d. No fork needed.

### Verify the devcontainer exists

```bash
ls .devcontainer/devcontainer.json
ls .devcontainer/setup-cluster.sh
```

The `setup-cluster.sh` runs automatically when a Codespace is created. It:
1. Installs k3d
2. Creates a k3d cluster (`drill-cluster`) with ports 80/443 mapped
3. Installs the nginx Ingress controller
4. Waits for everything to be ready

---

## Fully automated: one-command deploy

From the repo root:

```bash
cd codespace
./scripts/deploy-to-codespace.sh drill-app-django
```

This will:
1. Check that your changes are committed and pushed
2. Find an existing Codespace or create one
3. Copy the app folder to `~/drill-app` in the Codespace
4. Run `deploy.sh` inside the Codespace (build image, load into k3d, apply manifests, verify)

### Deploy a different app

```bash
./scripts/deploy-to-codespace.sh drill-app        # Flask
./scripts/deploy-to-codespace.sh drill-app-django  # Django
./scripts/deploy-to-codespace.sh drill-app-go      # Go
```

### Target a specific Codespace

```bash
./scripts/deploy-to-codespace.sh drill-app-go my-codespace-name
```

---

## Semi-automated: step by step

If the automation script hits issues, here's the manual path with `gh` CLI commands.

### 1. Push your branch

```bash
git add codespace/drill-app-django/ codespace/drill-app-go/ .devcontainer/
git commit -m "Add drill apps and devcontainer"
git push -u origin mac-eks-drill
```

### 2. Create a Codespace

```bash
CODESPACE_NAME=$(gh codespace create \
  -R KeyomaKriel/platform-drill-fastapi-postgres \
  -b mac-eks-drill \
  -m basicLinux32gb \
  --idle-timeout 30m \
  --default-permissions \
  -s)

echo "Codespace: $CODESPACE_NAME"
```

The `-s` flag streams postCreateCommand output (cluster setup) to stderr. Wait until it finishes (~3-5 minutes on first create).

### 3. List your Codespaces

```bash
gh codespace list -R KeyomaKriel/platform-drill-fastapi-postgres --json name,state,branch
```

### 4. Copy an app to the Codespace

```bash
# Pick one:
APP=drill-app-django
# APP=drill-app-go
# APP=drill-app

gh codespace ssh -c "$CODESPACE_NAME" -- 'rm -rf ~/drill-app'
gh codespace cp -r ./codespace/$APP remote:~/drill-app -c "$CODESPACE_NAME"
```

### 5. Deploy inside the Codespace

```bash
gh codespace ssh -c "$CODESPACE_NAME" -- 'bash ~/drill-app/deploy.sh'
```

Or SSH in interactively and deploy yourself (the actual drill):

```bash
gh codespace ssh -c "$CODESPACE_NAME"
# Now inside the Codespace:
cd ~/drill-app
script -q -a ./session.log
# Orient yourself, build, deploy...
```

### 6. Verify from your Mac

Forward port 80 from the Codespace:

```bash
gh codespace ports forward 80:8080 -c "$CODESPACE_NAME" &
curl http://localhost:8080/
curl http://localhost:8080/api/v1/status
```

---

## Drill session workflow

### Start a drill

```bash
gh codespace ssh -c "$CODESPACE_NAME"
cd ~/drill-app
script -q -a ./session.log
```

If the app is **not yet deployed** (orientation/implementation drill), deploy it yourself as practice. If it's **already deployed** (debugging drill), verify it's healthy first, then inject a fault.

### Between drills: clean up and redeploy a different app

Inside the Codespace:

```bash
# Delete the current app
kubectl delete namespace fleet-ops       # or incident-mgmt or warehouse-sys
rm -rf ~/drill-app

# Exit back to your Mac, then deploy the next app
exit
```

From your Mac:

```bash
gh codespace ssh -c "$CODESPACE_NAME" -- 'rm -rf ~/drill-app'
gh codespace cp -r ./codespace/drill-app-go remote:~/drill-app -c "$CODESPACE_NAME"
# Either deploy automatically or do it yourself as practice:
# gh codespace ssh -c "$CODESPACE_NAME" -- 'bash ~/drill-app/deploy.sh'
```

### Retrieve session logs

```bash
gh codespace cp -c "$CODESPACE_NAME" remote:~/drill-app/session.log ./session.log
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
- Final image is ~15MB vs ~150MB for Python
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
# Check existing codespaces (max 2 on free tier)
gh codespace list
# Delete old ones
gh codespace delete -c <name>
```

### Cluster not ready after Codespace creation

SSH in and check:

```bash
gh codespace ssh -c "$CODESPACE_NAME"
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
# Check if the ingress controller sees the ingress resource
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
```

### Port 80 already in use

If another app's namespace is still deployed, its ingress may conflict. Delete the old namespace first:

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
CODESPACE_NAME=$(gh codespace create -R KeyomaKriel/platform-drill-fastapi-postgres -b mac-eks-drill -m basicLinux32gb --idle-timeout 30m --default-permissions)

# Deploy an app
gh codespace cp -r ./codespace/drill-app-django remote:~/drill-app -c "$CODESPACE_NAME"
gh codespace ssh -c "$CODESPACE_NAME" -- 'bash ~/drill-app/deploy.sh'

# SSH in for a drill
gh codespace ssh -c "$CODESPACE_NAME"

# Pull session log
gh codespace cp -c "$CODESPACE_NAME" remote:~/drill-app/session.log ./session.log

# Clean up between apps
gh codespace ssh -c "$CODESPACE_NAME" -- 'kubectl delete namespace incident-mgmt && rm -rf ~/drill-app'

# Delete codespace
gh codespace delete -c "$CODESPACE_NAME"
```
