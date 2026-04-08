# Kubernetes Troubleshooting Handbook

A practical handbook for repo-based Platform Engineer interview practice. Built around the troubleshooting routing tree: symptom first, root cause second.

This handbook covers:
- The troubleshooting method (how to route from symptom to root cause)
- The 11 root-cause failure domains (what to check, how to fix, what to say)
- Reference material (commands, exit codes, HTTP codes)

It is scoped to **repo-based practical interviews**: orientation, debugging, small changes, and evidence-based reasoning about realistic app/deployment/runtime issues. It is not a general Kubernetes reference.

## Table of Contents

- [Rule 0](#rule-0)
- [Repo-First Orientation](#repo-first-orientation)
- [Entry Modes](#entry-modes)
- [Troubleshooting Sequence](#troubleshooting-sequence)
- [Symptom vs Root Cause](#symptom-vs-root-cause)
- [Symptom-to-Domain Table](#symptom-table)
- Failure Domains
  - [Startup / Crash](#startup-crash)
  - [Image Pull / Container Creation](#image-pull)
  - [Probe Failure](#probe-failure)
  - [Config / Secret / Env](#config-env)
  - [Service Routing / Port / Endpoint](#service-routing)
  - [DNS / Service Discovery / Namespace](#dns-namespace)
  - [Resource / Scheduling / Storage](#resource-scheduling)
  - [Ingress / External Routing](#ingress)
  - [NetworkPolicy / Traffic Restriction](#networkpolicy)
  - [RBAC / Service Account / Permission](#rbac)
  - [Application-Level Dependency / Runtime](#app-level)
- Additional Routing Sections
  - [Deployment / Rollout](#deployment-rollout)
  - [Jobs / CronJobs](#jobs-cronjobs)
- [Quick Reference](#quick-reference)
- [Appendix A: Exit Codes and Pod Statuses](#appendix-exit-codes)
- [Appendix B: HTTP Status Codes](#appendix-http)

---

<a id="rule-0"></a>
## Rule 0

Do not start by guessing the root cause.

Start by answering:

1. What is the visible symptom?
2. Which Kubernetes object is closest to that symptom?
3. What command will show the truth fastest?

---

<a id="repo-first-orientation"></a>
## Repo-First Orientation

### What this is for

Before you touch the cluster, spend 60-90 seconds building a mental model of four things:

1. **What the app does** — endpoints, purpose, expected behaviour.
2. **What it depends on** — databases, caches, external services, env vars.
3. **How it runs in a container** — base image, startup command, exposed port.
4. **How it runs in Kubernetes** — deployments, services, ingress, config injection, network rules.

This model is what lets you define "healthy," spot mismatches between intent and reality, and reason about where a fault could live. Without it, you are guessing.

In a real interview the repo may be only partly documented. The README may be incomplete or absent. You will often have to infer the system from code, manifests, Dockerfile, and config files. That is normal and expected — the interviewer is watching whether you can orient yourself from primary sources, not whether you found a wiki page.

### Where to look — practical search order

Work top-down. Each layer fills in what the previous one missed.

| Priority | Source | What you are looking for |
|----------|--------|--------------------------|
| 1 | **README / docs** | App purpose, endpoints, setup instructions, known dependencies |
| 2 | **App entrypoint / main file** | Routes, startup logic, database init, error handling |
| 3 | **Config / settings / env loading** | Which env vars the app reads, defaults, required vs optional |
| 4 | **Dependency files** | `requirements.txt`, `package.json`, `go.mod` — runtime deps and their versions |
| 5 | **Dockerfile** | Base image, build steps, exposed port, startup command |
| 6 | **K8s manifests / Helm / Kustomize** | Deployments, Services, Ingress, ConfigMaps, Secrets, NetworkPolicies |
| 7 | **Helper scripts / Makefile / CI config** | Build commands, deploy commands, test commands, pipeline steps |

You do not need to read everything. Scan for the key facts at each layer, then move on.

### What to look for in each place

#### App entrypoint and routes

Find the main application file (e.g. `main.py`, `app.js`, `main.go`). Look for:

- **Registered routes / endpoints** — these define what the app is supposed to serve. These are what you will curl to verify end-to-end.
- **Startup logic** — does the app connect to a database on startup? Create tables? Run migrations? If startup depends on an external service being reachable, the app will crash if that service is down.
- **Error handling** — does the app crash on connection failure, or retry? This affects whether a transient dependency issue causes a restart loop or just degraded responses.

#### Environment variables and config

Look for where the app loads configuration. Identify:

- **Which env vars the app expects** — database host, port, credentials, feature flags. Required vs defaulted.
- **What happens if a var is missing** — crash, fallback to default, or silent misbehaviour.
- **Where the values come from in K8s** — ConfigMaps, Secrets, or hardcoded in the Deployment spec. Cross-reference with the manifests.

#### Dockerfile

Key lines:

- **`FROM`** — base image. Tells you language runtime and whether debug tools are available inside the container.
- **`COPY` / `ADD`** — what gets put into the image and where.
- **`EXPOSE`** — the port the app listens on inside the container. Cross-reference with Service `targetPort` and probe definitions.
- **`CMD` / `ENTRYPOINT`** — the actual startup command. If this is wrong, the container will crash or hang.

#### Kubernetes manifests

Scan the manifest directory. For each resource type:

**Deployment:** `image` and `imagePullPolicy`, `replicas`, `env` / `envFrom`, `resources`, readiness/liveness probes (path, port, timing), init containers, `serviceAccountName`.

**Service:** `selector` (must match pod labels exactly), `port` and `targetPort` (targetPort must match container port).

**Ingress:** `host` and `path` rules, `ingressClassName`, backend service name and port (must match Service `port`, not `targetPort`).

**ConfigMap / Secret:** Key names must match what the app expects. Whether referenced via `envFrom` or individual `env[].valueFrom`.

**NetworkPolicy:** What traffic is allowed/denied. Default-deny policies require explicit allow rules for every required flow.

### Identifying the deploy path

The deploy path answers: **how do repo changes become running changes in the cluster?**

| Clue | Deploy method |
|------|--------------|
| `k8s/*.yaml` with no `Chart.yaml` or `kustomization.yaml` | Raw manifests — `kubectl apply -f k8s/` |
| `Chart.yaml` + `values.yaml` + `templates/` | Helm — `helm install` or `helm upgrade` |
| `kustomization.yaml` | Kustomize — `kubectl apply -k` |
| `Makefile` / `justfile` with deploy targets | Scripted — read the target |
| `imagePullPolicy: Never` with `:local` tag | Images loaded directly (kind/minikube) |

You need the deploy path before you make any fix — applying a fix the wrong way means it won't take effect or gets overwritten.

### How to narrate your orientation

**Narrate as you open each file** — say what you are looking at, what you found, and what it tells you. Do not read silently then summarise. Talking as you go fills silence, shows prioritisation, and lets the interviewer follow your thinking.

Structure in three phases: understand the app (from the repo), understand the deployment (Dockerfile + manifests), then verify it live on the cluster. Within the first two, narrate file by file.

#### Phase 1 — Understand the app (file by file)

> *"Let me start by looking at the repo structure. I can see an app directory, a Dockerfile, a k8s directory with manifests, requirements.txt, and a README. So this looks like a Python app with Kubernetes deployment config — raw manifests, no Helm or Kustomize."*

> *"Opening main.py. I can see three endpoints: root, /health, and /items. There's a startup call that connects to Postgres and seeds data. If Postgres is down at startup, this will crash — no retry logic."*

> *"The app reads POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD from env vars. Those come from ConfigMaps and Secrets in the manifests."*

#### Phase 2 — Understand the deployment (file by file)

> *"The Dockerfile builds from python:3.13-slim, exposes port 8000, starts Uvicorn on that port. So the container listens on 8000 — I'll want to check that the Service and probes target the same port."*

> *"The Deployment uses imagePullPolicy Never — local image. Env vars from app-config ConfigMap and app-secret Secret. Readiness probe on /health port 8000. Init container waits for Postgres."*

> *"Service maps port 80 to targetPort 8000. Ingress routes / to the Service on port 80. Full path: client → localhost:80 → Ingress → Service:80 → pod:8000."*

#### Phase 3 — Verify it live

> *"Let me verify. Pods are Running and Ready, both services have endpoints. Curling through the Ingress: root returns app info, health returns ok, items returns the seeded rows. Working end-to-end."*

Tips:
- **Name specific things.** "It reads POSTGRES_HOST from app-config" beats "it uses env vars."
- **Connect layers as you go.** "targetPort 8000 matches the Dockerfile EXPOSE" shows you are verifying consistency.
- **Mention failure modes.** "No retry logic means Postgres must be up at startup" shows operational understanding.
- **Say what you have not checked.** "I haven't verified the NetworkPolicies" is better than skipping silently.
- **Aim for about two minutes total.** Hit the key facts per file, then verify.

---

<a id="entry-modes"></a>
## Entry Modes

There are two ways to start. Pick one based on what you know.

### Full Triage

**Use when:** scope is ambiguous, multiple things may be broken, or the scenario is "investigate this cluster."

Say: *"The scope is unclear, so I'm going to orient broadly before I commit to a direction."*

Start cluster-wide:

```bash
kubectl config current-context
kubectl get ns
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
kubectl get ingress -A
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

From `get ns` and `get pods -A`, identify the target namespace. Once found, focus there:

```bash
kubectl config set-context --current --namespace=<ns>
kubectl get all -n <ns>
kubectl get ingress -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

As soon as you see a clear signal, stop broad triage and commit to a failure domain.

Full triage takes under a minute. Do not skip it when scope is unclear.

### Fast Path

**Use when:** you know the app, you know the symptom, you just don't know the cause.

The rule: **known app + known symptom + unknown cause = Fast Path.**

Say: *"This looks like a single workload problem, so I'm going straight to pods, then logs, then testing reachability layer by layer."*

1. `kubectl get pods -n <ns>` — check pod status
2. `kubectl describe pod <pod> -n <ns>` + `kubectl logs <pod> -n <ns>` — identify the failure
3. If pods healthy, test pod: `kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>` then `curl -i localhost:8080/`
4. If pod responds, test service: `kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>` then `curl -i localhost:8080/`
5. If service works, test ingress: `curl -i localhost/` or `curl -i -H "Host: <host>" localhost/` if the Ingress has a host rule

You can start with full triage and switch to fast path once you have a signal. That is usually the safest pattern: 20-40 seconds of orientation, then commit.

---

<a id="troubleshooting-sequence"></a>
## Troubleshooting Sequence

This is the practical method for live use. Follow it step by step.

### 1. Orient

Avoid wrong context or namespace.

```bash
kubectl config current-context
kubectl get ns
```

If wrong, fix before touching anything else.

### 2. Identify the workload

If not already known from the scenario prompt:

```bash
kubectl get pods -n <ns>
kubectl get deploy -n <ns>
kubectl get svc -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

Say: *"I'm looking at the full picture — what's running, what's failing, and any recent events."*

### 3. Check pod state

```bash
kubectl get pods -n <ns>
```

Read STATUS, READY, and RESTARTS.

**If pods are not healthy** → go to step 4 (classify pod symptom).

**If pods are healthy** (Running, Ready, low restarts) → go to step 6 (reachability path).

**If no pods exist** → check: does the Deployment exist? Right namespace? Right replica count? See [Deployment / Rollout](#deployment-rollout) or [DNS / Namespace](#dns-namespace).

### 4. Classify pod symptom

Pod symptom tells you where to look. It is **not** the root cause (see [Symptom vs Root Cause](#symptom-vs-root-cause)).

| Pod symptom | Route to |
|---|---|
| `ImagePullBackOff` / `ErrImagePull` / `ErrImageNeverPull` | [Image Pull / Container Creation](#image-pull) |
| `CreateContainerConfigError` / `CreateContainerError` | [Image Pull / Container Creation](#image-pull) (often reroutes to [Config / Secret / Env](#config-env)) |
| `Pending` (not scheduling) | [Resource / Scheduling / Storage](#resource-scheduling) |
| `CrashLoopBackOff` / `Error` / `Init:CrashLoopBackOff` | **Symptom hub** — go to step 5 |
| `Running` but `0/1` (not Ready) | [Probe Failure](#probe-failure) |
| `Running`, Ready, but RESTARTS climbing | [Probe Failure](#probe-failure) (liveness) |

### 5. CrashLoopBackOff — use logs to route to root cause

CrashLoopBackOff tells you *where to start*. Logs tell you the *root-cause branch*.

```bash
kubectl describe pod <pod> -n <ns>       # State, Last State, exit codes, Events
kubectl logs <pod> -n <ns>               # current attempt
kubectl logs <pod> -n <ns> --previous    # last crashed attempt
kubectl logs <pod> -c <init> -n <ns>     # init container if Init:* status
```

| What logs say | Route to |
|---|---|
| Missing ConfigMap / Secret / key reference | [Config / Secret / Env](#config-env) |
| Wrong env value (bad hostname, wrong DB, wrong password) | [Config / Secret / Env](#config-env) |
| `Name or service not known` / DNS failure | [DNS / Namespace](#dns-namespace) (cross-check: if the hostname value itself is wrong → [Config / Secret / Env](#config-env)) |
| Connection refused / timed out to dependency | [App-Level Dependency](#app-level) (cross-check: if the host/port value is wrong → [Config / Secret / Env](#config-env)) |
| Auth failure to dependency | [Config / Secret / Env](#config-env) or [App-Level Dependency](#app-level) (wrong creds → Config; dependency expects something else or app misuses creds → App-Level) |
| OOMKilled / exit code 137 | [Resource / Scheduling / Storage](#resource-scheduling) |
| App error / unhandled exception / missing module | [Startup / Crash](#startup-crash) |
| Command not found / exec format error | [Image Pull / Container Creation](#image-pull) |
| App starts then is killed by probes | [Probe Failure](#probe-failure) |
| Forbidden / permission denied on K8s API call | [RBAC / Service Account](#rbac) |

**Key principle:** When the log names a missing or wrong *value*, the root cause is usually Config / Secret / Env — even if the symptom looks like a connectivity or dependency issue.

### 6. Reachability path — test layer by layer

When pods are healthy, test from the inside out. Stop at the first layer that fails.

**A. Test Pod directly**

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i localhost:8080/
```

Try `/`, `/health`, or a known app path. The goal is to confirm the pod responds at all.

If no response → [App-Level Dependency](#app-level) or [Config / Secret / Env](#config-env).

**B. Test Service / Endpoints**

```bash
kubectl get endpoints <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

Empty endpoints → [Service Routing](#service-routing). Port mismatch → [Service Routing](#service-routing).

If pods are `0/1` Ready causing empty endpoints → the real problem is [Probe Failure](#probe-failure).

**C. Test Ingress / External path**

```bash
curl -i localhost/
curl -i -H "Host: <host>" localhost/    # if the Ingress has a host rule
```

If the Ingress specifies a `host`, a plain `curl localhost/` may hit the default backend and give a misleading result. Always check the Ingress spec for host rules and include the Host header when one is set.

Error or wrong backend → [Ingress / External Routing](#ingress).

Silent timeout (no error, no response) → consider [NetworkPolicy / Traffic Restriction](#networkpolicy) first, but also check for ingress controller issues, external routing problems, or hung backends.

Works → system is healthy end-to-end.

### 7. Special entry points

Some symptoms bypass the main pod-state → reachability flow and route directly:

| Symptom | Route to |
|---|---|
| Forbidden / Unauthorized | [RBAC / Service Account](#rbac) |
| Resources appear missing entirely | [DNS / Namespace](#dns-namespace) (namespace confusion) |
| PVC stuck in Pending / volume mount error | [Resource / Scheduling / Storage](#resource-scheduling) |
| Pods Running + Ready but app returns 5xx | [App-Level Dependency](#app-level) |
| Deployment exists but no pods (rollout stuck) | [Deployment / Rollout](#deployment-rollout) → route new RS pods through step 4 |

### 8. Apply the smallest justified fix

Change ONE thing for ONE reason. Do not shotgun multiple edits.

Follow the correct deploy path (identified during repo-first orientation):
- Code/config change → rebuild image → load into cluster → apply manifests
- Manifest-only change → `kubectl apply`
- Runtime cluster fix → `kubectl patch` / `kubectl set`

### 9. Verify end-to-end

Do not stop at "pods are Running."

```bash
kubectl get pods -n <ns>                    # Running, Ready, no new restarts
kubectl get endpoints <svc> -n <ns>         # populated
kubectl port-forward pod/<pod> 8080:<port>  # pod responds
kubectl port-forward svc/<svc> 8080:<port>  # service responds
curl -i localhost/                          # ingress/external path responds
curl -i -H "Host: <host>" localhost/        # if Ingress has a host rule
```

Test all known app endpoints. If the Ingress has a host rule, use the Host header — a plain curl may hit the default backend. If any step fails, return to step 3 with the new symptom.

Say: *"I've applied the fix. Now I'm verifying end-to-end — pods, endpoints, and an actual request through the full path."*

---

<a id="symptom-vs-root-cause"></a>
## Symptom vs Root Cause

This distinction is central to the troubleshooting method and must be internalised.

**Symptoms** are what you observe first. They tell you where to start looking.

**Root-cause domains** are where the fix lives. They are what you route *to* based on evidence.

The same symptom can route to different root causes:

| Symptom | Possible root cause |
|---|---|
| CrashLoopBackOff | Config / Secret / Env (wrong value), DNS / Namespace (bad hostname), Startup / Crash (app bug), Resource (OOMKilled), Probe Failure (killed by liveness) |
| 503 from Ingress | Probe Failure (readiness failing → empty endpoints), Service Routing (selector mismatch), App-Level (app returning errors) |
| Empty endpoints | Service Routing (selector mismatch), Probe Failure (pods not Ready) |
| Connection refused in logs | App-Level (dependency down), Config / Secret / Env (wrong host/port), DNS / Namespace (hostname won't resolve) |

**CrashLoopBackOff is the most important example.** It is a symptom hub, not a root cause. It tells you the container is crashing. Logs tell you *why* — and the "why" determines which failure domain to work in.

The routing tree's job is to take you from symptom to the correct root-cause domain. The failure domain sections below tell you what to do once you get there.

---

<a id="symptom-table"></a>
## Symptom-to-Domain Table

Use this to jump from what you see (or hear in the scenario prompt) to the right failure domain.

| What you see or hear | Domain | Go to |
|---|---|---|
| Forbidden / Unauthorized / "service account can't do X" | RBAC | [RBAC](#rbac) |
| `ImagePullBackOff` / `ErrImagePull` / `ErrImageNeverPull` | Image pull | [Image Pull](#image-pull) |
| `CreateContainerConfigError` / `CreateContainerError` | Container creation | [Image Pull / Container Creation](#image-pull) |
| `CrashLoopBackOff` / "app keeps restarting" | Symptom hub | Use logs to route (step 5 above) |
| Pod exit code 137 / OOMKilled | Resource limits | [Resource / Scheduling](#resource-scheduling) |
| `Pending` / "pods won't schedule" | Scheduling / resources | [Resource / Scheduling](#resource-scheduling) |
| `Init:CrashLoopBackOff` or `Init:0/1` | Init container | Use logs to route (step 5 above) |
| Pod `Running` but `0/1` | Readiness probe | [Probe Failure](#probe-failure) |
| Pod `Running` + `1/1` but RESTARTS climbing | Liveness probe | [Probe Failure](#probe-failure) |
| Events show missing ConfigMap or Secret | Config injection | [Config / Secret / Env](#config-env) |
| Pods healthy but app unreachable through Service | Service routing | [Service Routing](#service-routing) |
| Service works (port-forward OK) but external URL fails | Ingress | [Ingress](#ingress) |
| Everything looks healthy but traffic silently times out | Consider NetworkPolicy first | [NetworkPolicy](#networkpolicy) (also check ingress controller, external routing, hung backends) |
| PVC stuck in `Pending` / volume mount errors | Storage | [Resource / Scheduling](#resource-scheduling) |
| Deployment exists but pods not appearing | Rollout | [Deployment / Rollout](#deployment-rollout) |
| Pods Running + Ready but app returns 5xx | Application-level | [App-Level](#app-level) |
| Resources appear missing entirely | Namespace confusion | [DNS / Namespace](#dns-namespace) |
| `Name or service not known` / DNS failure | DNS | [DNS / Namespace](#dns-namespace) |

If multiple signals compete, pick the one closest to the root. Pod issues before Service issues. Config issues before app crash issues.

Say: *"The strongest signal I'm seeing is [X], so I'm treating this as a [domain] problem. Let me dig into that specifically."*

---

## Failure Domains

The 11 primary root-cause domains aligned with the drill model. Each section follows the same structure: entry criteria, commands, output interpretation, likely fixes, verification, narration practice, and docs links.

---

<a id="startup-crash"></a>
### 1. Startup / Crash

**You are here because** logs (from step 5) show an app-level crash: unhandled exception, missing module, bad syntax, stack trace, or exit code 1 with an application error. The container process itself is failing.

This is the domain when the root cause is the app code or image, not an external config or dependency issue. If logs point to a wrong config value or an unreachable dependency, route to [Config / Secret / Env](#config-env) or [App-Level Dependency](#app-level) instead.

Say: *"The logs show the app is crashing on startup with [error]. This is the app itself failing, not a config or dependency issue."*

#### Commands

```bash
kubectl describe pod <pod> -n <ns>                    # State, Last State, exit codes, Events
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous                 # last crashed attempt
kubectl logs <pod> -c <container> -n <ns>             # init containers or sidecars
```

#### Exit code reference

| Code | Meaning | Next step |
|---|---|---|
| `0` | Clean exit (unexpected for long-running app) | Check `restartPolicy`, command/args |
| `1` | Application error | Read the logs — stack trace, missing import, bad syntax |
| `137` | OOMKilled (128 + 9) | Route to [Resource / Scheduling](#resource-scheduling) |
| `139` | Segfault | Image/binary issue |
| `143` | SIGTERM | Usually liveness kill → route to [Probe Failure](#probe-failure) |

#### Init container failures

If the pod shows `Init:0/1` or `Init:CrashLoopBackOff`:

Say: *"The init container hasn't completed. The main container won't start until it succeeds."*

```bash
kubectl describe pod <pod> -n <ns>                           # find init container name
kubectl logs <pod> -c <init-container> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.initContainers[0].command}'
```

Compare the hostname/port the init container is waiting on against actual services:

```bash
kubectl get svc -n <ns>
kubectl get endpoints <svc> -n <ns>
```

Usually you fix what the init container is waiting on, not the init container itself.

#### Likely fixes

**App crash from bad image:** `kubectl rollout undo deploy/<deploy> -n <ns>`

**Container exits with no logs (bad command/args):** `kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 5 "command\|args"` — correct or remove the override with `kubectl edit deployment <deploy> -n <ns>`.

**App crash from bad config:** Fix the ConfigMap/Secret (see [Config / Secret / Env](#config-env)), then `kubectl rollout restart deploy/<deploy> -n <ns>`.

#### Verify

```bash
kubectl get pods -n <ns>
kubectl logs <pod> -n <ns>
# Restarts stop climbing, pod stays Running, logs are clean
```

#### Narration practice

*"Exit code is 1, so the app itself is crashing. Logs show an ImportError — a missing module. This is an image problem. Let me check the deployment history for the last known-good image."*

#### Official docs

- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pods/)
- [Determine the Reason for Pod Failure](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/)

---

<a id="image-pull"></a>
### 2. Image Pull / Container Creation

**You are here because** the pod shows `ImagePullBackOff`, `ErrImagePull`, `ErrImageNeverPull`, `CreateContainerConfigError`, or `CreateContainerError`.

Say: *"The pod is stuck at [status]. I need to check the Events section to see exactly what failed."*

Note: `ErrImageNeverPull` means `imagePullPolicy: Never` but the image doesn't exist on the node. Common in kind/minikube where images are loaded directly.

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].image}'
```

To find the correct (previously working) image:

```bash
kubectl rollout history deploy/<deploy> -n <ns>
kubectl rollout history deploy/<deploy> -n <ns> --revision=<N>
```

#### What the output usually implies

**Image pull failures** (`ImagePullBackOff`, `ErrImagePull`):
- Events show `Failed to pull image "myapp:badtag"` — compare against the known-good image.
- `unauthorized: authentication required` — check `imagePullSecrets`.
- Typo in registry/repo/tag, or missing registry prefix.

**Container creation failures** (`CreateContainerConfigError`, `CreateContainerError`):

| Status | Typical cause | What to check |
|---|---|---|
| `CreateContainerConfigError` | Pod references a Secret or ConfigMap that doesn't exist | Events name the missing object |
| `CreateContainerConfigError` | Key referenced via `valueFrom` doesn't exist in the object | Check the specific key |
| `CreateContainerError` | Entrypoint or command doesn't exist in the image | Check `command`/`args` in pod spec |
| `CreateContainerError` | Security context violation | Check Events for security context messages |

Note: `CreateContainerConfigError` from a missing ConfigMap/Secret is closely related to [Config / Secret / Env](#config-env). Fix the missing object, and the pod will proceed.

#### Likely fixes

```bash
# Fix image name or tag
kubectl set image deployment/<deploy> <container>=<correct-image>:<tag> -n <ns>

# If you don't know the container name
kubectl get deployment <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[*].name}'

# Rollback entirely
kubectl rollout undo deploy/<deploy> -n <ns>

# Create missing ConfigMap/Secret causing CreateContainerConfigError
kubectl create configmap <cm> --from-literal=KEY=value -n <ns>
kubectl create secret generic <secret> --from-literal=KEY=value -n <ns>
```

`kubectl rollout undo` reverts the entire pod template. `kubectl set image` changes only the image.

#### Verify

```bash
kubectl get pods -n <ns> -w
# Pod moves past the error state and reaches Running
```

#### Narration practice

*"The pod is stuck in ImagePullBackOff. Events show 'manifest unknown' for the tag. The image name looks right but the tag doesn't exist. Let me check the deployment history for the last known-good image."*

#### Official docs

- [Images](https://kubernetes.io/docs/concepts/containers/images/)
- [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

---

<a id="probe-failure"></a>
### 3. Probe Failure

**You are here because** the pod is `Running` but not Ready (`0/1`), or Running with RESTARTS climbing. Step 4 routed you here from pod symptom classification, or step 5 routed you here because logs show the app is being killed by probes.

Say: *"The pod is Running but [not Ready / restarts are climbing]. I need to check which probe is failing and what it's targeting."*

#### Readiness probe

Pod is `Running` but `0/1` — won't receive traffic until readiness passes.

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].readinessProbe}'
```

Look for `Readiness probe failed` in Events. Note the path, port, and timing.

**Test what the app actually responds to:**

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i localhost:8080/
curl -i localhost:8080/health
curl -i localhost:8080/healthz
```

Compare the configured probe path/port against what actually returns 200.

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path | Path returns 404, different path returns 200 | Edit deploy, fix path |
| Wrong probe port | `connection refused` on probe | Edit deploy, fix port |
| initialDelaySeconds too short | Fails briefly then passes | Increase initialDelaySeconds |
| App genuinely unhealthy | Probe correct, app has a real problem | Check logs → [App-Level](#app-level) |

#### Liveness probe

Pod is `Running` and Ready but restarts keep climbing.

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].livenessProbe}'
```

Same diagnostic approach: port-forward and curl the probe path manually. If path/port is correct but app is slow, check `timeoutSeconds` against actual response time.

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path or port | Same as readiness | Edit deploy, fix path/port |
| Timing too aggressive | App responds correctly but slowly | Increase `timeoutSeconds`, `periodSeconds`, or `failureThreshold` |
| App genuinely unhealthy | Probe is correct, app crashes under load | Fix the app, not the probe |

#### Likely fixes

```bash
kubectl edit deploy <deploy> -n <ns>
# Fix readinessProbe.httpGet.path, .port, .initialDelaySeconds
# Fix livenessProbe.httpGet.path, .port, .timeoutSeconds, .failureThreshold
```

#### Verify

```bash
kubectl get pods -n <ns>                  # 1/1 Ready (readiness) or restarts stop (liveness)
kubectl get endpoints <svc> -n <ns>       # endpoints populate once readiness passes
```

#### Narration practice

*"The pod is Running but 0/1 Ready — readiness probe is failing. The probe targets /healthz on port 8080, but the app logs show routes registered on port 8000. The probe port is wrong."*

#### Official docs

- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

<a id="config-env"></a>
### 4. Config / Secret / Env

**You are here because** events show a missing ConfigMap or Secret, step 5 log routing found a wrong or missing value, or a `CreateContainerConfigError` pointed to a missing config reference.

This is one of the most common failure domains. It covers: missing objects, wrong reference names, wrong keys, wrong values, and mount issues.

Say: *"This is a configuration problem. I need to check what the pod references versus what actually exists, and compare the values."*

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].envFrom}'
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A2 -E 'configMapRef|secretRef'
```

#### What the output usually implies

**Events:** `configmap "<cm>" not found` or `secret "<secret>" not found` — names the exact missing resource.

**`envFrom` references:** Compare character-for-character against what exists. Common: typo like `app-configs` vs `app-config`.

**Values inside existing objects:**

```bash
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
kubectl exec <pod> -n <ns> -- env | sort
```

Cross-reference runtime env against what the app expects (from repo-first orientation) and against what actually exists in the cluster (service names, database names, etc.).

#### Likely fixes

**Missing ConfigMap or Secret:** Find expected name from deployment spec. Create: `kubectl create configmap <cm> --from-literal=KEY=value -n <ns>` or `kubectl create secret generic <secret> --from-literal=KEY=value -n <ns>`.

**Wrong reference name in Deployment:** `kubectl edit deploy <deploy> -n <ns>` — correct `envFrom[].configMapRef.name` or `secretRef.name`.

**Wrong value in existing object:** `kubectl edit configmap <cm> -n <ns>` or `kubectl edit secret <secret> -n <ns>` (values must be base64-encoded).

After any config change, pods must be restarted to pick up new values:

```bash
kubectl rollout restart deploy/<deploy> -n <ns>
```

#### Verify

```bash
kubectl describe pod <pod> -n <ns>               # no Warning events about missing objects
kubectl exec <pod> -n <ns> -- env | grep <KEY>   # correct values injected
kubectl logs <pod> -n <ns>                        # clean startup
```

#### Narration practice

*"Events show 'configmap app-configs not found'. There's app-config but the deployment references app-configs with an extra 's'. Classic typo. Fixing the reference."*

*"Logs show 'password authentication failed'. Let me decode the secret and compare against what Postgres expects. The password value is wrong — fixing the secret and restarting."*

#### Official docs

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

<a id="service-routing"></a>
### 5. Service Routing / Port / Endpoint

**You are here because** the reachability path (step 6B) found empty endpoints or a port mismatch. Pods are Running and Ready but unreachable through the Service.

Say: *"Pods are healthy but I can't reach them through the Service. I need to check selectors, endpoints, and ports."*

#### Commands

```bash
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

#### What the output usually implies

**Endpoints:** The single most decisive check. Healthy: `10.244.x.x:8000`. Broken: `<none>` — Service selector matches zero Ready pods.

**Selector mismatch:** Compare `kubectl describe svc` Selector field exactly against `kubectl get pods --show-labels`. Any character difference means no match: `app=api` vs `app=platform-drill-api`.

**Wrong targetPort:** TargetPort must match the container's listening port. Find it: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].ports[0].containerPort}'`.

**Pods not Ready = empty endpoints:** Even if the selector matches, only `1/1` Ready pods appear in endpoints. If pods show `0/1`, fix readiness first → [Probe Failure](#probe-failure).

#### Likely fixes

```bash
# Selector mismatch
kubectl patch svc <svc> -n <ns> -p '{"spec":{"selector":{"app":"<correct-label>"}}}'

# Wrong targetPort
kubectl patch svc <svc> -n <ns> -p '{"spec":{"ports":[{"port":<svc-port>,"targetPort":<correct-port>}]}}'
```

#### Verify

```bash
kubectl get endpoints <svc> -n <ns>               # pod IPs populated
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/                            # valid response
curl -s localhost/                                 # end-to-end through Ingress
```

Do not stop at port-forward. The external curl proves the full path.

#### Narration practice

*"Endpoints show none. Service selector says app=api, but pods have app=platform-drill-api. That's the mismatch. Patching the service selector."*

#### Official docs

- [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

---

<a id="dns-namespace"></a>
### 6. DNS / Service Discovery / Namespace

**You are here because** resources appear missing, DNS resolution fails, or step 5 log routing found `Name or service not known`.

Say: *"I need to check whether I'm looking in the right place, and whether DNS resolution is working inside the cluster."*

#### Namespace confusion

Resources exist but `kubectl get` returns nothing — you're targeting the wrong namespace.

```bash
kubectl get all -A
kubectl get ns
kubectl config view --minify | grep namespace
```

**Fixes:**

- Wrong default namespace: `kubectl config set-context --current --namespace=<correct-ns>`
- Cross-namespace service reference: use FQDN `<service>.<namespace>.svc.cluster.local`

#### DNS / service discovery

Pod logs show `Name or service not known`, `no such host`, or connections fail to a hostname.

```bash
kubectl exec <pod> -n <ns> -- nslookup <hostname>
kubectl get svc -n <ns>
```

Compare the hostname the app uses (from logs or `kubectl exec -- env`) against actual Service names. Common: app uses `database` but the service is named `postgres`.

**If no hostnames resolve at all** (even `kubernetes.default`):

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get networkpolicy -n <ns>
```

A missing DNS egress NetworkPolicy will silently break all name resolution → [NetworkPolicy](#networkpolicy).

#### Verify

```bash
kubectl exec <pod> -n <ns> -- nslookup <service>
# Returns a valid cluster IP
```

#### Narration practice

*"I can't find the resources I expect. Let me check if they're in a different namespace. Found them — they're in default, not drill."*

#### Official docs

- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

<a id="resource-scheduling"></a>
### 7. Resource / Scheduling / Storage

**You are here because** the pod is `Pending`, exit code is 137 (OOMKilled), or PVC is stuck in `Pending`.

Say: *"The pod is [Pending / OOMKilled / has a storage issue]. Let me find the specific constraint that's blocking it."*

#### Pending pods

```bash
kubectl describe pod <pod> -n <ns>
kubectl get nodes
kubectl describe node <node>
kubectl top nodes
```

The scheduler message in Events names the exact blocker:

| Event message | Cause | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | Requests exceed node capacity | Lower requests in deploy spec |
| `no nodes available to schedule` | Taint/affinity/selector mismatch | Check taints, fix tolerations or nodeSelector |
| `unbound immediate PersistentVolumeClaim` | PVC can't bind | See Storage below |

#### OOMKilled (exit 137)

```bash
kubectl describe pod <pod> -n <ns>          # Last State shows OOMKilled
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].resources.limits.memory}'
kubectl top pod <pod> -n <ns>               # if metrics available
```

Fix: `kubectl edit deploy <deploy> -n <ns>` — increase `resources.limits.memory`. Confirm usage is near the limit first.

#### Storage (PVC issues)

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get storageclass
kubectl get pv
```

**PVC STATUS:** `Bound` = healthy. `Pending` = no PV matched.

| Event message | Cause | Fix |
|---|---|---|
| `no persistent volumes available` | No matching PV/StorageClass | Check `storageClassName` on PVC vs available StorageClasses |
| `storageclass "X" not found` | PVC references nonexistent class | Fix or create the StorageClass |
| Capacity or access mode mismatch | PV doesn't meet PVC requirements | Adjust capacity or access modes |

PVC fields are mostly immutable — delete and recreate if the spec is wrong.

#### Verify

```bash
kubectl get pvc -n <ns>       # Bound
kubectl get pods -n <ns>      # Running, Ready
curl -s localhost/             # end-to-end
```

#### Narration practice

*"The pod is Pending. Describe shows 'Insufficient memory' — requests exceed what the node can allocate. The pod requests 4Gi but the node only has 3.5Gi allocatable. Lowering the request."*

#### Official docs

- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

<a id="ingress"></a>
### 8. Ingress / External Routing

**You are here because** the reachability path (step 6C) found that the Service works via port-forward but the external URL fails.

**Important:** If Service/endpoints are broken, go to [Service Routing](#service-routing) first. Do not blame Ingress when the chain underneath is broken.

Say: *"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer."*

#### Commands

```bash
kubectl get ingress -n <ns>
kubectl describe ingress <ing> -n <ns>
kubectl get ingressclass
kubectl get pods -n ingress-nginx
```

#### What the output usually implies

**ADDRESS column:** Healthy: an IP or `localhost`. Blank: ingress controller hasn't admitted this resource.

**IngressClass:** Must match installed controller. `kubectl get ingressclass` shows what's available.

**Rules > Backends:** Backend service name and port must match an existing Service. The ingress backend port must match the service `port`, not the `targetPort`.

**Host and Path:** If `Host:` is set, requests need a matching Host header. `pathType: Exact` with `/api` won't match `/`.

**Controller health:** `kubectl get pods -n ingress-nginx` — must be Running and Ready.

#### Likely fixes

```bash
# Wrong backend port
kubectl patch ingress <ing> -n <ns> --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":<correct-port>}]'

# Wrong backend service name
kubectl patch ingress <ing> -n <ns> --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"<correct-svc>"}]'

# Wrong IngressClass
kubectl patch ingress <ing> -n <ns> -p '{"spec":{"ingressClassName":"nginx"}}'
```

#### Verify

```bash
kubectl get ingress -n <ns>                      # ADDRESS populated
kubectl describe ingress <ing> -n <ns>           # Backends show correct service with endpoints
curl -s localhost/                                # end-to-end
curl -s -H "Host: <host>" localhost/             # if Ingress has a host rule
```

#### Narration practice

*"Port-forward to the service works fine, but curl localhost fails. The ingress backend points to port 8080 but the service is on port 80. Patching the ingress."*

#### Official docs

- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

---

<a id="networkpolicy"></a>
### 9. NetworkPolicy / Traffic Restriction

**You are here because** everything looks correct — pods Running, Ready, endpoints populated — but traffic silently fails or times out with no error message. NetworkPolicy is the most common cause in this scenario, but also consider ingress controller issues, external routing problems, or hung backends before committing.

Say: *"Everything looks healthy but traffic is failing silently. When all the obvious things check out, NetworkPolicy is the first thing I check — but I'll also verify the ingress controller is healthy."*

#### Commands

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
kubectl get pods -n <ns> --show-labels
```

#### What the output usually implies

**POD-SELECTOR column:** `<none>` (empty `podSelector: {}`) applies to ALL pods in the namespace.

**Common broken patterns:**
- Allow rule `podSelector` doesn't match any running pods (label typo)
- Allow rule `namespaceSelector` wrong — for ingress-nginx traffic, need `kubernetes.io/metadata.name: ingress-nginx`
- Missing port specification in allow rule
- No DNS egress rule — pods can't resolve hostnames at all
- Egress deny with no rule allowing app-to-database traffic

#### Quick isolation test (interview/sandbox only)

Temporarily delete policies one at a time and test after each:

```bash
kubectl get networkpolicy -n <ns> -o name
kubectl delete networkpolicy <policy-name> -n <ns>
curl localhost/
```

If traffic works after deleting a specific policy, that was the blocker. Re-apply a corrected version.

**Do not do this in production.** In production, diagnose by reading policy specs and comparing selectors.

#### Likely fixes

**Wrong podSelector in allow rule:** `kubectl edit networkpolicy <policy> -n <ns>` — fix `podSelector.matchLabels`.

**Missing allow rule (e.g., app-to-database egress):**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-db
  namespace: <ns>
spec:
  podSelector:
    matchLabels:
      app: <app-label>
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: <db-label>
      ports:
        - protocol: TCP
          port: 5432
EOF
```

**Missing DNS egress rule:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

#### Verify

```bash
kubectl get networkpolicy -n <ns>
curl -s localhost/                   # traffic flows end-to-end
```

#### Narration practice

*"Everything looks correct — pods Running, endpoints populated, selector matches — but traffic silently times out. First I'll check the ingress controller is Running, then look at NetworkPolicies. There's a default-deny-ingress policy but no allow rule for traffic from ingress-nginx. That's the blocker. Adding the allow policy."*

#### Official docs

- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

<a id="rbac"></a>
### 10. RBAC / Service Account / Permission

**You are here because** you saw Forbidden, Unauthorized, or a service account cannot perform an action. This is a special entry point (step 7) — it bypasses the main pod-state flow.

Say: *"I see a Forbidden error. I need to check the ServiceAccount, Role, and RoleBinding to find the broken link in the chain."*

#### Commands

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
kubectl get sa,role,rolebinding -n <ns>
kubectl get rolebinding <binding> -n <ns> -o yaml
kubectl get role <role> -n <ns> -o yaml
```

If you don't know the SA name: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.serviceAccountName}'`

#### What the output usually implies

Walk the chain when `auth can-i` returns `no`:

**RoleBinding `subjects` field:**
- `name` must exactly match the SA name (check for typos, e.g., `app` vs `app-sa`)
- `namespace` must match where the SA lives (omitted = silent mismatch)
- `kind` must be `ServiceAccount`

**RoleBinding `roleRef` field:**
- `name` must match an existing Role
- `roleRef` is immutable — if wrong, delete and recreate the binding

**Role `rules` field — all three must be correct:**

| Field | Common mistake |
|---|---|
| `apiGroups` | `["v1"]` instead of `[""]` for core resources |
| `resources` | `["pod"]` singular instead of `["pods"]` plural |
| `verbs` | `["read"]` is not valid; use `["get","list","watch"]` |

Common apiGroups: `pods`, `services`, `configmaps`, `secrets` → `[""]`. `deployments`, `replicasets` → `["apps"]`. `ingresses`, `networkpolicies` → `["networking.k8s.io"]`. If unsure: `kubectl api-resources | grep <resource>`

#### Likely fixes

**Subject name or namespace wrong:** `kubectl edit rolebinding <binding> -n <ns>` — correct `subjects[].name` and `subjects[].namespace`.

**RoleRef wrong (immutable):** Delete and recreate:

```bash
kubectl delete rolebinding <binding> -n <ns>
kubectl create rolebinding <binding> \
  --role=<correct-role> \
  --serviceaccount=<ns>:<sa> \
  -n <ns>
```

**Role missing permissions:** `kubectl edit role <role> -n <ns>` — add missing verb/resource/apiGroup.

**ServiceAccount doesn't exist:** `kubectl create serviceaccount <sa> -n <ns>`

#### Verify

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
# Expected: yes
```

#### Narration practice

*"The `auth can-i` check returns no. The SA exists, so either the RoleBinding is pointing to the wrong SA, or the Role doesn't have the right verbs. Found it — the binding has the wrong namespace on the subject."*

#### Official docs

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)

---

<a id="app-level"></a>
### 11. Application-Level Dependency / Runtime

**You are here because** pods are Running and Ready, endpoints are populated, but the app returns errors, doesn't respond, or the reachability path (step 6A) found the pod itself is not working correctly. Kubernetes thinks everything is fine — this is an app-level issue.

Say: *"Everything looks healthy from a Kubernetes perspective. This is an application-level issue. Logs should tell me what's going on."*

#### Commands

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl exec <pod> -n <ns> -- env | sort
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
```

#### What the output usually implies

| Log message | Cause | How to find correct value |
|---|---|---|
| `connection refused` to DB host | Wrong hostname or DB not running | `kubectl get svc -n <ns>` — Service NAME = correct hostname |
| `password authentication failed` | Wrong credentials | Compare decoded Secret against authoritative source |
| `database "X" does not exist` | Wrong DB name in config | Compare pod env against Postgres ConfigMap |
| `relation "X" does not exist` | Schema not initialized | App may need restart after config fix |
| `Name or service not known` | DNS can't resolve hostname | `kubectl get svc -n <ns>` — use exact Service name |
| App returns 404 on expected paths | Wrong base path or route config | Check env vars for `BASE_PATH`/`ROOT_PATH` |

**Diagnostic pattern:** (1) `kubectl exec <pod> -- env | sort` to see runtime values, (2) compare each value against the authoritative source — `kubectl get svc` for hostnames, ConfigMap for DB name/user, decoded Secret for passwords.

Note: If the root cause is a wrong config *value* (not a missing object or wrong reference), it may overlap with [Config / Secret / Env](#config-env). Use whichever domain fits the specific fix.

#### Likely fixes

**Wrong ConfigMap value:** `kubectl edit configmap <cm> -n <ns>`, then `kubectl rollout restart deploy/<deploy> -n <ns>`.

**Wrong Secret value:** `kubectl edit secret <secret> -n <ns>` (base64-encoded), then `kubectl rollout restart deploy/<deploy> -n <ns>`.

**Schema not initialized:** `kubectl rollout restart deploy/<deploy> -n <ns>` — if the app runs migrations on startup, a clean restart after fixing config may resolve it.

#### Verify

```bash
kubectl logs <pod> -n <ns>                   # no connection or auth errors
kubectl exec <pod> -n <ns> -- env | sort     # env vars correct
curl -s localhost/                           # app responds through full path
```

#### Narration practice

*"Pods are Running, Ready, endpoints look good — Kubernetes thinks everything is fine. But the app returns 500. Logs show 'password authentication failed'. The credentials in the Secret don't match what Postgres expects."*

#### Official docs

- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pods/)

---

## Additional Routing Sections

These are not primary root-cause domains. They are views into problems whose real root cause lives in one of the 11 domains above.

---

<a id="deployment-rollout"></a>
### Deployment / Rollout

**You are here because** the deployment exists but new pods aren't appearing or the rollout seems stuck. This is not a root cause — the actual problem is in the new ReplicaSet's pods.

Say: *"The rollout seems stuck. Let me check the new ReplicaSet's pods to find the actual failure."*

#### Commands

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl describe deploy <deploy> -n <ns>
```

#### What the output usually implies

**ReplicaSets:** Old RS `1 1 1`, new RS `1 1 0` = new pods never became Ready, old RS still serving.

Check the new RS's pods for a status and **route through the normal troubleshooting sequence** (step 4):
- `ImagePullBackOff` → [Image Pull](#image-pull)
- `CrashLoopBackOff` → step 5 log routing
- `0/1` Ready → [Probe Failure](#probe-failure)

#### Likely fixes

**Bad image tag:** `kubectl set image deploy/<deploy> <container>=<correct-image>:<tag> -n <ns>`

**Full rollback:** `kubectl rollout undo deploy/<deploy> -n <ns>`

When to use which: `set image` when only the image was wrong. `rollout undo` when you want to revert everything to the last working revision.

#### Verify

```bash
kubectl rollout status deploy/<deploy> -n <ns>    # successfully rolled out
kubectl get rs -n <ns>                             # one RS at desired count
kubectl get pods -n <ns>                           # all Running 1/1
curl -i localhost/                                 # end-to-end
curl -i -H "Host: <host>" localhost/               # if Ingress has a host rule
```

#### Official docs

- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

<a id="jobs-cronjobs"></a>
### Jobs / CronJobs

**You are here because** the scenario involves batch or scheduled work. Job pod failures route through the normal troubleshooting sequence (step 4).

Say: *"This is a Job or CronJob issue. I need to check whether the job itself is misconfigured or if the pods it creates are failing."*

#### Commands

```bash
kubectl get jobs -n <ns>
kubectl get cronjobs -n <ns>
kubectl describe job <job> -n <ns>
kubectl get pods -n <ns> --selector=job-name=<job>
kubectl logs <job-pod> -n <ns>
```

#### What the output usually implies

- **COMPLETIONS** `0/1` after sufficient time: pod is failing — check the pod status via step 4.
- **CronJob SUSPEND** `True`: paused, won't fire.
- **LAST SCHEDULE** `<none>`: bad schedule syntax, never fires.

#### Likely fixes

**Pod failing:** Fix the root cause via the normal failure domains, then delete and recreate the Job (Jobs are immutable).

**CronJob suspended:** `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"suspend":false}}'`

**Bad schedule syntax:** `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"schedule":"<correct-cron>"}}'`

**Test immediately:** `kubectl create job <job>-test --from=cronjob/<cj> -n <ns>`

#### Official docs

- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

---

<a id="quick-reference"></a>
## Quick Reference

```bash
# Orientation
kubectl config current-context
kubectl get ns
kubectl get pods -A
kubectl get all -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp

# Pod diagnostics
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -c <container> -n <ns>
kubectl exec <pod> -n <ns> -- env | sort

# Service diagnostics
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels

# Config diagnostics
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# Network diagnostics
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>

# Deployment diagnostics
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>

# Storage diagnostics
kubectl get pvc -n <ns>
kubectl get storageclass

# RBAC diagnostics
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>

# Common fixes
kubectl edit deploy <deploy> -n <ns>
kubectl set image deploy/<deploy> <container>=<image>:<tag> -n <ns>
kubectl rollout restart deploy/<deploy> -n <ns>
kubectl rollout undo deploy/<deploy> -n <ns>
kubectl patch svc <svc> -n <ns> -p '<json>'

# Reachability testing (layer by layer)
kubectl port-forward pod/<pod> 8080:<port> -n <ns>
kubectl port-forward svc/<svc> 8080:<port> -n <ns>
curl -i localhost:8080/              # test via port-forward
curl -i localhost/                   # test via ingress
curl -i -H "Host: <host>" localhost/ # test via ingress with host rule
```

---

<a id="appendix-exit-codes"></a>
## Appendix A: Exit Codes and Pod Statuses

### Container Exit Codes

| Code | Meaning | Typical cause | Next step |
|---|---|---|---|
| 0 | Success | Normal for init containers and Jobs | Unexpected for long-running apps — check command/args |
| 1 | Application error | Unhandled exception, config error | `kubectl logs --previous` → [Startup / Crash](#startup-crash) |
| 2 | Shell builtin misuse | Bad command syntax in spec | Check `command`/`args` |
| 126 | Not executable | Wrong permissions | Check image |
| 127 | Command not found | Binary missing from image | Check image contents |
| 137 | OOMKilled (128+9) | Exceeded memory limit | [Resource / Scheduling](#resource-scheduling) |
| 139 | Segfault (128+11) | App bug or corrupt binary | Check image |
| 143 | SIGTERM (128+15) | Normal shutdown or liveness kill | If unexpected: [Probe Failure](#probe-failure) |

### Pod Statuses

| Status | Meaning | Route to |
|---|---|---|
| Running | Containers started | Check READY column — `0/1` → [Probe Failure](#probe-failure) |
| Pending | Not scheduled | [Resource / Scheduling](#resource-scheduling) |
| CrashLoopBackOff | Repeated crashes | Symptom hub — use logs to route (step 5) |
| ImagePullBackOff / ErrImagePull | Image pull failed | [Image Pull](#image-pull) |
| CreateContainerConfigError | Missing Secret/ConfigMap ref | [Image Pull / Container Creation](#image-pull) |
| CreateContainerError | Bad command or security context | [Image Pull / Container Creation](#image-pull) |
| OOMKilled | Memory limit exceeded | [Resource / Scheduling](#resource-scheduling) |
| Init:0/1 / Init:CrashLoopBackOff | Init container failing | [Startup / Crash](#startup-crash) (init section) |
| Completed | Exited cleanly | Normal for Jobs, unexpected for Deployments |

### Common Event Reasons

| Reason | Meaning | Route to |
|---|---|---|
| FailedScheduling | No suitable node | [Resource / Scheduling](#resource-scheduling) |
| FailedMount | Volume can't mount | [Resource / Scheduling](#resource-scheduling) or [Config / Secret / Env](#config-env) |
| Unhealthy | Probe failed | [Probe Failure](#probe-failure) |
| Killing | Container killed | If unexpected: [Probe Failure](#probe-failure) |
| BackOff | Backing off restart/pull | [Startup / Crash](#startup-crash) or [Image Pull](#image-pull) |
| Forbidden | RBAC denied | [RBAC](#rbac) |
| FailedCreate | RS can't create pod | [Deployment / Rollout](#deployment-rollout) |

---

<a id="appendix-http"></a>
## Appendix B: HTTP Status Codes

| Code | Meaning | Interview context |
|---|---|---|
| 200 | OK | Expected healthy response |
| 404 | Not Found | Wrong probe path → [Probe Failure](#probe-failure). Wrong Ingress path → [Ingress](#ingress) |
| 500 | Internal Server Error | App crash — check logs → [App-Level](#app-level) |
| 502 | Bad Gateway | Proxy got invalid response — check endpoints, pod readiness → [Service Routing](#service-routing) |
| 503 | Service Unavailable | No healthy backend — check readiness, selector, endpoints → [Service Routing](#service-routing) |
| 504 | Gateway Timeout | Upstream too slow — check app performance, resource limits → [App-Level](#app-level) |
| 403 | Forbidden | Auth issue — check RBAC → [RBAC](#rbac) |
