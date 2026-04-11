# Repo Orientation Crammer

**Interview Repo Orientation**

Read files in order. Extract tagged facts. Summarize by bucket at the end.

---

## Mental model (for summarizing, not reading order)

| Shape | Start | Supply | Ship | Signals |
|-------|-------|--------|------|---------|

You don't walk through these one at a time. You read files in order and tag what you find. The buckets organize your summary at the end.

---

## Phase 1 — Scan (30 seconds)

### Get the repo map

Run these commands. Don't open any files yet.

```
ls
tree -L 2          # or: find . -maxdepth 2 -type f | sort
cat README.md      # skim only — what is this app, how to run it
```

> *"I'm mapping the repo first — where the app code is, where the build config is, and where the Kubernetes manifests live."*

---

## Phase 2 — Read key files (3-4 minutes)

Open files in this order. Extract tagged facts from each.

Each file feeds multiple buckets. Don't jump between files — read one, extract everything, move on.

### Dockerfile

- **[Shape]** Base image, language, build steps
- **[Start]** CMD / ENTRYPOINT — what process runs
- **[Start]** EXPOSE — what port the container expects

> *"The Dockerfile tells me this is a `[language]` app running `[process]` on port `[N]`."*

### Main app file (app.py / main.go / index.js / ...)

- **[Start]** Listening port, startup logic, DB init
- **[Supply]** Env vars it reads (DB host, creds, config)
- **[Signals]** Health/readiness endpoints, what they check
- **[Shape]** Routes/endpoints — what the app does

> *"The app listens on `[port]`, connects to `[DB]` using env vars `[X, Y, Z]`, and has endpoints `[list]`. Health check hits `[path]` and returns `[condition]`."*

### Deployment manifest

- **[Ship]** Image name/tag, replicas
- **[Ship]** Labels on pod template (used by Service selector)
- **[Start]** command / args (if overriding Dockerfile CMD)
- **[Supply]** env / envFrom — where config comes from
- **[Supply]** volumeMounts — any mounted files or PVCs
- **[Signals]** Probes — path, port, timing
- **[Ship]** initContainers — what must succeed before start

> *"The Deployment runs image `[X]`, pulls config from `[ConfigMap/Secret]`, has `[readiness/liveness]` probes on `[path:port]`, and an init container that `[does what]`."*

### ConfigMap + Secret manifests

- **[Supply]** Actual values: DB host, port, database name, creds
- **[Supply]** Cross-reference: do these match what the app code expects?

> *"Config points to `[DB host]` on port `[N]`, database `[name]`. Credentials are in `[Secret name]`. These match / don't match what the app reads."*

### Service manifest

- **[Ship]** Selector — must match Deployment pod labels
- **[Ship]** Port (what other things connect to) and targetPort (must match container port)
- **[Ship]** Type (ClusterIP / NodePort / LoadBalancer)

> *"Service selects pods with `[labels]`, maps port `[X]` to targetPort `[Y]`. That targetPort should match the container's listening port."*

### Ingress manifest

- **[Ship]** IngressClassName, host, path rules
- **[Ship]** Backend service name and port — must match Service
- **[Signals]** If this is wrong, curl from outside fails but pod-level curl works

> *"Ingress routes `[path]` to service `[name]` on port `[N]`. That should match the Service I just read."*

### Database Deployment + Service + PVC (if present)

- **[Supply]** DB image, version, credentials (must match app's config)
- **[Ship]** DB Service name (this is what the app uses as PGHOST / DB_HOST)
- **[Ship]** PVC — storage for data persistence
- **[Signals]** DB probes — pg_isready or similar

> *"Postgres runs as `[image:version]`, the Service name is `[X]` — that's what the app config should point to."*

### Signal commands to run

After reading the files, check the live cluster to see if reality matches what you read.

```
kubectl get pods -n [namespace]                # Are all pods Running + Ready?
kubectl get endpoints -n [namespace]           # Are endpoints populated for each Service?
kubectl describe pod [app-pod] -n [namespace]  # Events, probe status, env source errors
kubectl logs [app-pod] -n [namespace]          # Startup errors, DB connection failures
curl [host][path]                              # Hit each route from the Ingress — host/port/path come from what you just read
```

> *"Files told me what should happen. These commands tell me what is actually happening. Any gap between the two is where the problem lives."*

---

## Phase 3 — Summarize (30 seconds)

Now narrate what you know, organized by bucket.

This is when the mental model matters. Speak through each bucket in order.

### Shape

> "This is a `[framework]` API with `[N]` endpoints for `[purpose]`, backed by `[database]`, deployed via `[raw manifests / Helm / Kustomize]` into the `[namespace]` namespace."

### Start

> "Containerized with Docker — runs `[process]` on port `[N]`. On startup it `[connects to DB / runs migrations / seeds data]`. If the DB isn't reachable, `[it crashes / retries / degrades]`. `[Init container waits for X / no init container]`."

### Supply

> "The app needs `[N]` env vars for `[database]` — `[list them]`. These come from ConfigMap `[name]` and Secret `[name]`. DB host points to service `[name]`. Creds and DB name `[match / don't match]` between the app config and the database config."

### Ship

> "Deployment runs `[N]` replicas with `[readiness / liveness]` probes on `[path:port]`. Service maps port `[X]` to targetPort `[Y]`. Ingress routes `[path]` to the service on port `[X]` via `[nginx / traefik]`. Labels and selectors `[match / don't match]` throughout."

### Signals

> "If the DB is down, the app `[crashes / degrades]` — I'd see `[CrashLoopBackOff / 503s]` and connection errors in logs. If probes fail, endpoints would be empty. If the Service selector is wrong, endpoints empty but pods Running. If Ingress is wrong, direct pod curl works but external curl doesn't."

---

## What not to do

- Don't try to fill buckets one at a time — you'll re-read files
- Don't read the whole codebase — just the main file
- Don't explain business logic in depth
- Don't start fixing before you've read the key files
- Don't narrate while reading — extract first, narrate at the end

## The connection chain to verify

```
App code reads env var PGHOST
  → Deployment envFrom references ConfigMap
    → ConfigMap value = DB Service name
      → DB Service selector = DB pod labels
        → DB pod is Running + Ready

App listens on port 7600
  → Deployment containerPort = 7600
    → Service targetPort = 7600
      → Ingress backend port = Service port
        → curl localhost/ works
```

---

*The mental model organizes your summary. The file order organizes your reading. Don't mix them up.*
