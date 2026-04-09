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

The README may be incomplete or absent. You will often have to infer the system from code, manifests, Dockerfile, and config files. That is normal — the interviewer is watching whether you can orient yourself from primary sources, not whether you found a wiki page.

**Narrate as you go** — don't read silently then summarise. Each step below is written as a narration flow: do this, say this, look for this. Talking fills silence, shows prioritisation, and lets the interviewer follow your thinking in real time.

### Step 1 — Repo structure (always do this first)

`ls` the top level. **"Let me start by looking at the repo structure."** Scan for app code directory, Dockerfile, manifest directory (`k8s/`, `deploy/`, `manifests/`), `Chart.yaml` / `kustomization.yaml`, Makefile, README. **"I can see [what's there]. This looks like a [language] app with [deploy method]."**

### Step 2 — App entrypoint (almost always open this)

Open the main application file (e.g. `main.py`, `app.js`, `main.go`). **"Opening the main app file to understand what it serves and what it depends on."** Look for **registered routes/endpoints** (these are what you curl to verify), **startup logic** (database connections, migrations, seed data), and **error handling** (crash vs retry). **"I can see [N] endpoints: [list them]. At startup it [what it does]. If [dependency] is down, it will [crash / retry / degrade]."**

If the entrypoint shows which env vars it reads, note them. Otherwise, move to step 3.

### Step 3 — Dockerfile (almost always open this)

**"Checking the Dockerfile for the listening port and startup command."** Key lines: `FROM` (base image, debug tools?), **`EXPOSE`** (the **container port** — cross-reference with Service `targetPort` and probes later), `CMD`/`ENTRYPOINT` (if wrong, container crashes or hangs). **"Container listens on port [port], started by [command]. I'll check the Service and probes target the same port."**

### Step 4 — Deployment manifest (always open this)

The most important manifest. **"Now looking at the Deployment to see how the app is configured in the cluster."** Look for and name each out loud: **image** and **imagePullPolicy**, **env/envFrom** (where config comes from), **readiness/liveness probes** (path, port, timing), **init containers**, **resources**, **serviceAccountName**. **"Image is [name], pull policy is [policy]. Env vars come from [source]. Probes target [path] on port [port] — that [matches / doesn't match] the Dockerfile EXPOSE."** Connect layers as you go: **"targetPort [X] matches the container port"** shows you are verifying consistency, not just reading.

### Step 5 — Service manifest (always open this)

**"Checking the Service to see how traffic reaches the app."** Look for **selector** (must match pod labels exactly) and **port/targetPort** (targetPort must match the container port from step 3). **"Service selects [label]. Maps port [X] to targetPort [Y] — lines up with the container port."**

### Step 6 — Ingress manifest (open if it exists)

**"Checking the Ingress for external routing."** Look for **ingressClassName**, **host and path rules**, backend **service name and port** (must match Service `port`, not `targetPort`). **"Traffic flows: client → [entrypoint] → Ingress → Service:[port] → pod:[port]. Ports line up across all layers."**

### Step 7 — ConfigMap and Secret (open if debugging, skim if orienting)

During orientation: **"ConfigMap and Secret exist and are referenced by the Deployment — I'll verify values if I need to debug."**

During debugging: compare actual values against what the app reads and what exists in the cluster. **"[Key] is set to [value] — that [matches / doesn't match] what the app expects."** See [Config / Secret / Env](#config-env) for detailed diagnostics.

### Files you can usually skip or skim

| File | When to open it |
|------|----------------|
| **README** | Glance at it first — if it describes the app and endpoints, great. If it's thin or absent, move on. Don't spend time here. |
| **Config / settings module** | Only if the app entrypoint doesn't show which env vars it reads. Follow the import if you need to. |
| **Dependency files** (`requirements.txt`, `package.json`) | One glance to confirm the framework. Rarely need more. |
| **NetworkPolicy** | Only if debugging silent traffic failures. During orientation, note whether policies exist but don't read them in detail. |
| **RBAC manifests** | Only if debugging Forbidden errors. Not needed during orientation. |
| **Helper scripts / Makefile / CI config** | Only if you can't figure out the deploy path from the manifests and Dockerfile. |

### Deploy path (identify this during orientation, don't skip it)

The deploy path answers: **how do repo changes become running changes in the cluster?** You need this before you make any fix.

| Clue | Deploy method |
|------|--------------|
| `k8s/*.yaml` with no `Chart.yaml` or `kustomization.yaml` | Raw manifests — `kubectl apply -f k8s/` |
| `Chart.yaml` + `values.yaml` + `templates/` | Helm — `helm install` or `helm upgrade` |
| `kustomization.yaml` | Kustomize — `kubectl apply -k` |
| `Makefile` / `justfile` with deploy targets | Scripted — read the target |
| `imagePullPolicy: Never` with `:local` tag | Images loaded directly (kind/minikube) |

You usually identify the deploy path from what you saw in steps 1, 3, and 4 — no separate step needed. **"The deploy path is: [build step] → [load step] → [apply step]."**

### Step 8 — Verify it live

Move to the cluster. **"Now I'll verify the running state matches what the repo says."**

```bash
kubectl get pods -n <ns>
kubectl get endpoints -n <ns>
curl -i localhost/
curl -i -H "Host: <host>" localhost/    # if Ingress has a host rule
```

Test all known endpoints from step 2. **"Pods are [status], endpoints are [populated/empty]. Curling through Ingress: [result]. Working end-to-end."**

If something fails, say what you **expected** versus what you **got**. That is the start of debugging — transition to [Entry Modes](#entry-modes) and the [Troubleshooting Sequence](#troubleshooting-sequence).

### Orientation tips

- **Name specific things.** "It reads [VAR] from [source]" beats "it uses env vars."
- **Mention failure modes.** "No retry logic means [dependency] must be up at startup" shows operational understanding.
- **Say what you have not checked.** "I haven't verified the NetworkPolicies" is better than skipping silently.
- **Aim for about two minutes total.** Hit the key facts per file, then verify.

---

<a id="entry-modes"></a>
## Entry Modes

There are two ways to start. Pick one based on what you know.

### Full Triage

**Use when:** scope is ambiguous, multiple things may be broken, or the scenario is "investigate this cluster."

**"The scope is unclear, so I'm going to orient broadly before I commit to a direction."**

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

**"This looks like a single workload problem, so I'm going straight to pods, then logs, then testing reachability layer by layer."**

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

<a id="step-1"></a>
### 1. Orient

```bash
kubectl config current-context
kubectl get ns
kubectl config set-context --current --namespace=<ns>
```

**"Let me make sure I'm in the right context and namespace before I touch anything."** If wrong, fix before proceeding.

<a id="step-2"></a>
### 2. Identify the workload

If not already known from the scenario prompt:

```bash
kubectl get pods -n <ns>
kubectl get deploy -n <ns>
kubectl get svc -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

**"I'm looking at the full picture — what's running, what's failing, and any recent events."**

<a id="step-3"></a>
### 3. Check pod state

```bash
kubectl get pods -n <ns>
```

**"Looking at STATUS, READY, and RESTARTS."** Read all three columns — they route you.

**If pods are not healthy** → **"Pods aren't healthy — let me classify the symptom."** Go to [step 4](#step-4).

**If pods are healthy** (Running, Ready, low restarts) → **"Pods look healthy. Let me test reachability layer by layer."** Go to [step 6](#step-6).

**If no pods exist** → **"No pods — I need to check whether the Deployment exists, the namespace is right, and replicas are set."** See [Deployment / Rollout](#deployment-rollout) or [DNS / Namespace](#dns-namespace).

<a id="step-4"></a>
### 4. Classify pod symptom

**"The pod status tells me where to look — it's not the root cause itself."** See [Symptom vs Root Cause](#symptom-vs-root-cause).

| Pod symptom | Route to |
|---|---|
| `ImagePullBackOff` / `ErrImagePull` / `ErrImageNeverPull` | [Image Pull / Container Creation](#image-pull) |
| `CreateContainerConfigError` / `CreateContainerError` | [Image Pull / Container Creation](#image-pull) (often reroutes to [Config / Secret / Env](#config-env)) |
| `Pending` (not scheduling) | [Resource / Scheduling / Storage](#resource-scheduling) |
| `CrashLoopBackOff` / `Error` / `Init:CrashLoopBackOff` | **Symptom hub** — go to [step 5](#step-5) |
| `Running` but `0/1` (not Ready) | [Probe Failure](#probe-failure) |
| `Running`, Ready, but RESTARTS climbing | [Probe Failure](#probe-failure) (liveness) |

<a id="step-5"></a>
### 5. CrashLoopBackOff — use logs to route to root cause

**"CrashLoopBackOff tells me the container is crashing. Logs will tell me why — that determines which failure domain I'm in."**

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

<a id="step-6"></a>
### 6. Reachability path — test layer by layer

**"Pods are healthy, so I'll test reachability from the inside out — pod, then service, then ingress. I'll stop at the first layer that fails."**

<a id="step-6a"></a>
**A. Test Pod directly**

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i localhost:8080/
```

Try `/`, `/health`, or a known app path. **"Testing the pod directly to confirm it responds at all."**

If no response → **"Pod itself isn't responding — this is an app-level or config issue."** [App-Level Dependency](#app-level) or [Config / Secret / Env](#config-env).

<a id="step-6b"></a>
**B. Test Service / Endpoints**

```bash
kubectl get endpoints <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

**"Checking endpoints first — if they're empty, the Service can't route to anything."** Empty endpoints → [Service Routing](#service-routing). Port mismatch → [Service Routing](#service-routing).

If pods are `0/1` Ready causing empty endpoints → **"Endpoints are empty because pods aren't Ready — fixing readiness first."** [Probe Failure](#probe-failure).

<a id="step-6c"></a>
**C. Test Ingress / External path**

```bash
curl -i localhost/
curl -i -H "Host: <host>" localhost/    # if the Ingress has a host rule
```

If the Ingress specifies a `host`, a plain `curl localhost/` may hit the default backend and give a misleading result. Always check the Ingress spec for host rules and include the Host header when one is set.

Error or wrong backend → **"Service port-forward works but external URL fails — problem is in the Ingress layer."** [Ingress / External Routing](#ingress).

Silent timeout (no error, no response) → **"Traffic is silently failing with no error. When everything else checks out, I look at NetworkPolicies first."** [NetworkPolicy / Traffic Restriction](#networkpolicy) (also check ingress controller, external routing, hung backends).

Works → **"Working end-to-end."**

<a id="step-7"></a>
### 7. Special entry points

Some symptoms bypass the main pod-state → reachability flow and route directly:

| Symptom | Route to |
|---|---|
| Forbidden / Unauthorized | [RBAC / Service Account](#rbac) |
| Resources appear missing entirely | [DNS / Namespace](#dns-namespace) (namespace confusion) |
| PVC stuck in Pending / volume mount error | [Resource / Scheduling / Storage](#resource-scheduling) |
| Pods Running + Ready but app returns 5xx | [App-Level Dependency](#app-level) |
| Deployment exists but no pods (rollout stuck) | [Deployment / Rollout](#deployment-rollout) → route new RS pods through [step 4](#step-4) |

<a id="step-8"></a>
### 8. Apply the smallest justified fix

**"I'm going to change one thing for one reason."** Do not shotgun multiple edits.

Follow the correct deploy path (identified during [Repo-First Orientation](#repo-first-orientation)):
- Code/config change → rebuild image → load into cluster → apply manifests
- Manifest-only change → `kubectl apply`
- Runtime cluster fix → `kubectl patch` / `kubectl set`

<a id="step-9"></a>
### 9. Verify end-to-end

**"I've applied the fix. Now I'm verifying end-to-end — pods, endpoints, and an actual request through the full path."** Do not stop at "pods are Running."

```bash
kubectl get pods -n <ns>                    # Running, Ready, no new restarts
kubectl get endpoints <svc> -n <ns>         # populated
kubectl port-forward pod/<pod> 8080:<port>  # pod responds
kubectl port-forward svc/<svc> 8080:<port>  # service responds
curl -i localhost/                          # ingress/external path responds
curl -i -H "Host: <host>" localhost/        # if Ingress has a host rule
```

Test all known app endpoints. If the Ingress has a host rule, use the Host header — a plain curl may hit the default backend. If any step fails, return to [step 3](#step-3) with the new symptom.

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
| `CrashLoopBackOff` / "app keeps restarting" | Symptom hub | Use logs to route ([step 5](#step-5)) |
| Pod exit code 137 / OOMKilled | Resource limits | [Resource / Scheduling](#resource-scheduling) |
| `Pending` / "pods won't schedule" | Scheduling / resources | [Resource / Scheduling](#resource-scheduling) |
| `Init:CrashLoopBackOff` or `Init:0/1` | Init container | Use logs to route ([step 5](#step-5)) |
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

**"The strongest signal I'm seeing is [X], so I'm treating this as a [domain] problem. Let me dig into that specifically."**

---

## Failure Domains

The 11 primary root-cause domains aligned with the drill model. Each section follows the same structure: entry criteria, commands, output interpretation, likely fixes, verification, narration practice, and docs links.

---

<a id="startup-crash"></a>
### 1. Startup / Crash

**You are here because** logs (from [step 5](#step-5)) show an app-level crash: unhandled exception, missing module, bad syntax, stack trace, or exit code 1 with an application error. The container process itself is failing.

**"The logs show the app is crashing on startup with [error]. This is the app itself failing, not a config or dependency issue."** If logs point to a wrong config value or an unreachable dependency, route to [Config / Secret / Env](#config-env) or [App-Level Dependency](#app-level) instead.

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
| `1` | Application error | **"Exit code 1 — the app itself is crashing."** Read the logs — stack trace, missing import, bad syntax |
| `137` | OOMKilled (128 + 9) | Route to [Resource / Scheduling](#resource-scheduling) |
| `139` | Segfault | Image/binary issue |
| `143` | SIGTERM | Usually liveness kill → route to [Probe Failure](#probe-failure) |

#### Init container failures

If the pod shows `Init:0/1` or `Init:CrashLoopBackOff`: **"The init container hasn't completed. The main container won't start until it succeeds."**

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

**"Restarts have stopped, pod is staying Running, logs are clean."**

#### Official docs

- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pods/)
- [Determine the Reason for Pod Failure](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/)

---

<a id="image-pull"></a>
### 2. Image Pull / Container Creation

**You are here because** the pod shows `ImagePullBackOff`, `ErrImagePull`, `ErrImageNeverPull`, `CreateContainerConfigError`, or `CreateContainerError`.

**"The pod is stuck at [status]. Let me check the Events section to see exactly what failed."** Note: `ErrImageNeverPull` means `imagePullPolicy: Never` but the image doesn't exist on the node — common in kind/minikube where images are loaded directly.

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
- Events show `Failed to pull image "myapp:badtag"` — **"The image name looks right but the tag doesn't exist. Let me check the deployment history for the last known-good image."** Compare against the known-good image.
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

**"Pod is past the error state and running."**

#### Official docs

- [Images](https://kubernetes.io/docs/concepts/containers/images/)
- [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)

---

<a id="probe-failure"></a>
### 3. Probe Failure

**You are here because** the pod is `Running` but not Ready (`0/1`), or Running with RESTARTS climbing. [Step 4](#step-4) routed you here from pod symptom classification, or [step 5](#step-5) routed you here because logs show the app is being killed by probes.

**"The pod is Running but [not Ready / restarts are climbing]. Let me check which probe is failing and what it's targeting."**

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
| Wrong probe path | Path returns 404, different path returns 200 | **"Probe targets [path] but the app responds on [other path]."** Fix path |
| Wrong probe port | `connection refused` on probe | **"Probe targets port [X] but the app listens on [Y]."** Fix port |
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

**"Pod is [1/1 Ready / restarts have stopped]. Endpoints are populated."**

#### Official docs

- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

<a id="config-env"></a>
### 4. Config / Secret / Env

**You are here because** events show a missing ConfigMap or Secret, [step 5](#step-5) log routing found a wrong or missing value, or a `CreateContainerConfigError` pointed to a missing config reference.

This is one of the most common failure domains. It covers: missing objects, wrong reference names, wrong keys, wrong values, and mount issues.

**"This is a configuration problem. I need to check what the pod references versus what actually exists, and compare the values."**

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].envFrom}'
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A2 -E 'configMapRef|secretRef'
```

#### What the output usually implies

**Events:** `configmap "<cm>" not found` or `secret "<secret>" not found` — **"Events name the exact missing resource: [name]. Let me check if it exists under a different name."** Compare character-for-character.

**`envFrom` references:** Compare character-for-character against what exists. **"The deployment references [name] but the actual object is [other name] — classic typo."**

**Values inside existing objects:**

```bash
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
kubectl exec <pod> -n <ns> -- env | sort
```

Cross-reference runtime env against what the app expects (from [Repo-First Orientation](#repo-first-orientation)) and against what actually exists in the cluster (service names, database names, etc.). **"The app expects [key] to be [value], but it's actually set to [other value]."**

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

**"No warning events, correct values injected, clean startup."**

#### Official docs

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)

---

<a id="service-routing"></a>
### 5. Service Routing / Port / Endpoint

**You are here because** the reachability path ([step 6B](#step-6b)) found empty endpoints or a port mismatch. Pods are Running and Ready but unreachable through the Service.

**"Pods are healthy but I can't reach them through the Service. Let me check selectors, endpoints, and ports."**

#### Commands

```bash
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

#### What the output usually implies

**Endpoints:** The single most decisive check. Healthy: `10.244.x.x:8000`. Broken: `<none>`. **"Endpoints are empty — the Service selector matches zero Ready pods. Let me compare the selector against actual pod labels."**

**Selector mismatch:** Compare `kubectl describe svc` Selector field exactly against `kubectl get pods --show-labels`. **"Service selector says [label], but pods have [other label] — that's the mismatch."** Any character difference means no match.

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

Do not stop at port-forward. The external curl proves the full path. **"Endpoints are populated, port-forward works, and the external curl returns a valid response."**

#### Official docs

- [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

---

<a id="dns-namespace"></a>
### 6. DNS / Service Discovery / Namespace

**You are here because** resources appear missing, DNS resolution fails, or [step 5](#step-5) log routing found `Name or service not known`.

**"I need to check whether I'm looking in the right place, and whether DNS resolution is working inside the cluster."**

#### Namespace confusion

Resources exist but `kubectl get` returns nothing — **"I can't find the resources I expect. Let me check if they're in a different namespace."**

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

Compare the hostname the app uses (from logs or `kubectl exec -- env`) against actual Service names. **"The app is trying to reach [hostname] but the actual service is named [other name]."** Common: app uses `database` but the service is named `postgres`.

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

#### Official docs

- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)

---

<a id="resource-scheduling"></a>
### 7. Resource / Scheduling / Storage

**You are here because** the pod is `Pending`, exit code is 137 (OOMKilled), or PVC is stuck in `Pending`.

**"The pod is [Pending / OOMKilled / has a storage issue]. Let me find the specific constraint that's blocking it."**

#### Pending pods

```bash
kubectl describe pod <pod> -n <ns>
kubectl get nodes
kubectl describe node <node>
kubectl top nodes
```

The scheduler message in Events names the exact blocker. **"Describe shows [event message] — [what it means]."**

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

#### Official docs

- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)

---

<a id="ingress"></a>
### 8. Ingress / External Routing

**You are here because** the reachability path ([step 6C](#step-6c)) found that the Service works via port-forward but the external URL fails.

**Important:** If Service/endpoints are broken, go to [Service Routing](#service-routing) first. Do not blame Ingress when the chain underneath is broken.

**"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer."**

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

**Rules > Backends:** Backend service name and port must match an existing Service. The ingress backend port must match the service `port`, not the `targetPort`. **"The ingress backend points to port [X] but the service is on port [Y]. That's the mismatch."**

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

#### Official docs

- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

---

<a id="networkpolicy"></a>
### 9. NetworkPolicy / Traffic Restriction

**You are here because** everything looks correct — pods Running, Ready, endpoints populated — but traffic silently fails or times out with no error message.

**"Everything looks healthy but traffic is failing silently. When all the obvious things check out, NetworkPolicy is the first thing I check — but I'll also verify the ingress controller is healthy."** Also consider ingress controller issues, external routing problems, or hung backends before committing.

#### Commands

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
kubectl get pods -n <ns> --show-labels
```

#### What the output usually implies

**POD-SELECTOR column:** `<none>` (empty `podSelector: {}`) applies to ALL pods in the namespace.

**Common broken patterns:**
- Allow rule `podSelector` doesn't match any running pods (label typo) — **"The allow rule targets [label] but no pods have that label."**
- Allow rule `namespaceSelector` wrong — for ingress-nginx traffic, need `kubernetes.io/metadata.name: ingress-nginx`
- Missing port specification in allow rule
- No DNS egress rule — **"There's no DNS egress rule — pods can't resolve hostnames at all."**
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

#### Official docs

- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

<a id="rbac"></a>
### 10. RBAC / Service Account / Permission

**You are here because** you saw Forbidden, Unauthorized, or a service account cannot perform an action. This is a special entry point ([step 7](#step-7)) — it bypasses the main pod-state flow.

**"I see a Forbidden error. I need to check the ServiceAccount, Role, and RoleBinding to find the broken link in the chain."**

#### Commands

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
kubectl get sa,role,rolebinding -n <ns>
kubectl get rolebinding <binding> -n <ns> -o yaml
kubectl get role <role> -n <ns> -o yaml
```

If you don't know the SA name: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.serviceAccountName}'`

#### What the output usually implies

**"auth can-i returns no. Let me walk the chain — ServiceAccount, RoleBinding, Role — to find the broken link."**

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

#### Official docs

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)

---

<a id="app-level"></a>
### 11. Application-Level Dependency / Runtime

**You are here because** pods are Running and Ready, endpoints are populated, but the app returns errors, doesn't respond, or the reachability path ([step 6A](#step-6a)) found the pod itself is not working correctly. Kubernetes thinks everything is fine — this is an app-level issue.

**"Everything looks healthy from a Kubernetes perspective. This is an application-level issue. Logs should tell me what's going on."**

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
| `connection refused` to DB host | Wrong hostname or DB not running | **"The app can't reach [host]. Let me check if the service exists."** `kubectl get svc -n <ns>` — Service NAME = correct hostname |
| `password authentication failed` | Wrong credentials | **"Auth is failing. Let me decode the secret and compare."** Compare decoded Secret against authoritative source |
| `database "X" does not exist` | Wrong DB name in config | Compare pod env against Postgres ConfigMap |
| `relation "X" does not exist` | Schema not initialized | App may need restart after config fix |
| `Name or service not known` | DNS can't resolve hostname | `kubectl get svc -n <ns>` — use exact Service name |
| App returns 404 on expected paths | Wrong base path or route config | Check env vars for `BASE_PATH`/`ROOT_PATH` |

**Diagnostic pattern:** (1) `kubectl exec <pod> -- env | sort` to see runtime values, (2) compare each value against the authoritative source — `kubectl get svc` for hostnames, ConfigMap for DB name/user, decoded Secret for passwords. **"The runtime env shows [key]=[value] but the actual [service/config] says [correct value]."**

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

#### Official docs

- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pods/)

---

## Additional Routing Sections

These are not primary root-cause domains. They are views into problems whose real root cause lives in one of the 11 domains above.

---

<a id="deployment-rollout"></a>
### Deployment / Rollout

**You are here because** the deployment exists but new pods aren't appearing or the rollout seems stuck. This is not a root cause — the actual problem is in the new ReplicaSet's pods.

**"The rollout seems stuck. Let me check the new ReplicaSet's pods to find the actual failure."**

#### Commands

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl describe deploy <deploy> -n <ns>
```

#### What the output usually implies

**ReplicaSets:** Old RS `1 1 1`, new RS `1 1 0` = new pods never became Ready, old RS still serving.

Check the new RS's pods for a status and **route through the normal troubleshooting sequence** ([step 4](#step-4)):
- `ImagePullBackOff` → [Image Pull](#image-pull)
- `CrashLoopBackOff` → [step 5](#step-5) log routing
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

**You are here because** the scenario involves batch or scheduled work. Job pod failures route through the normal troubleshooting sequence ([step 4](#step-4)).

**"This is a Job or CronJob issue. I need to check whether the job itself is misconfigured or if the pods it creates are failing."**

#### Commands

```bash
kubectl get jobs -n <ns>
kubectl get cronjobs -n <ns>
kubectl describe job <job> -n <ns>
kubectl get pods -n <ns> --selector=job-name=<job>
kubectl logs <job-pod> -n <ns>
```

#### What the output usually implies

- **COMPLETIONS** `0/1` after sufficient time: pod is failing — check the pod status via [step 4](#step-4).
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
| CrashLoopBackOff | Repeated crashes | Symptom hub — use logs to route ([step 5](#step-5)) |
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
