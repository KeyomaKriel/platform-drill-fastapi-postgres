# Drill 02 — Answer Key (Assessor Only)

**Round:** 04
**Drill:** 02
**Task type:** Single-fault debugging
**Failure domain:** Process startup / command override (Tier 2)
**App:** drill-app-django
**Namespace:** incident-mgmt

---

## Injected Fault

A `command` field was added to the main container (`incident-api`) in `api-deployment.yaml` that overrides the Dockerfile CMD with an incorrect WSGI module path.

**Injection method:**

Add the following `command` field to the `incident-api` container in the Deployment manifest, then apply:

```bash
# In api-deployment.yaml, under the incident-api container (after imagePullPolicy: Never), add:
#          command: ["gunicorn", "config.wsgi_app:application", "--bind", "0.0.0.0:8200", "--workers", "2"]

# Then apply:
kubectl apply -f /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/manifests/api-deployment.yaml -n incident-mgmt
```

Alternatively, inject via sed:

```bash
sed -i '/name: incident-api$/,/ports:/{/imagePullPolicy: Never/a\          command: ["gunicorn", "config.wsgi_app:application", "--bind", "0.0.0.0:8200", "--workers", "2"]
}' /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/manifests/api-deployment.yaml
kubectl apply -f /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/manifests/api-deployment.yaml -n incident-mgmt
```

**What changed:** The Dockerfile CMD is `["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8200", "--workers", "2"]`. The injected `command` field overrides this with `config.wsgi_app:application` (wrong module name). When Kubernetes runs the container, the `command` field takes precedence over the Dockerfile CMD. Gunicorn tries to import `config.wsgi_app`, which does not exist, and crashes with `ModuleNotFoundError`.

The init containers (`wait-for-db` and `run-migrations`) are **not affected** because they have their own `command` fields and do not use the Dockerfile CMD.

---

## What Happens

| Layer | Status |
|---|---|
| Init containers | Complete successfully (they have their own commands) |
| Main container (`incident-api`) | Crashes immediately with `ModuleNotFoundError` |
| Pod status | `CrashLoopBackOff` (new pods), old pods may still be `Running` due to rolling update strategy |
| Service endpoints | Partially populated (old pods) or empty (if all pods crash) |
| External curl | 502 Bad Gateway or times out (depending on endpoint state) |

The key subtlety: the init containers succeed, so the pod gets past the init phase. The main container starts, gunicorn tries to import the wrong module, and crashes. This creates a CrashLoopBackOff that is only visible by checking the main container, not the init containers.

With 2 replicas and the default rolling update strategy (`maxUnavailable: 25%`), the old pods may be preserved while the new pods crash, leading to a mixed state where some requests still work.

---

## Key Signals

| Signal | Where to find it | What it means |
|---|---|---|
| Pods in `CrashLoopBackOff` | `kubectl get pods -n incident-mgmt` | Main container is crashing on startup |
| `ModuleNotFoundError: No module named 'config.wsgi_app'` | `kubectl logs <pod> -n incident-mgmt` | Gunicorn cannot find the specified WSGI module |
| `command` field in container spec | `kubectl describe pod <pod> -n incident-mgmt` or `kubectl get deploy incident-api -n incident-mgmt -o yaml` | The Deployment has a command override that should not be there |
| Init containers completed | `kubectl describe pod <pod> -n incident-mgmt` shows init containers as `Completed` | The fault is in the main container, not init containers |
| `config.wsgi_app:application` in command | `cat manifests/api-deployment.yaml` or `kubectl get deploy -o yaml` | The wrong WSGI module name: `wsgi_app` instead of `wsgi` |
| Dockerfile CMD differs from manifest command | Compare `Dockerfile` CMD with manifest `command` | The `command` field overrides the Dockerfile CMD and introduces the typo |

---

## Ideal Diagnostic Path

### 1. Orient and confirm the symptom (~1 min)

```bash
# Check external access
curl -v http://localhost/

# Quick cluster overview
kubectl get pods,svc,endpoints -n incident-mgmt
```

**Say:** "Let me see what's happening. The curl is failing and I can see some pods are in CrashLoopBackOff. Let me dig into why the containers are crashing."

### 2. Check pod status and logs (~2 min)

```bash
kubectl get pods -n incident-mgmt
kubectl describe pod -l component=api -n incident-mgmt
kubectl logs -l component=api -n incident-mgmt --tail=50
```

**Say:** "The init containers completed fine but the main container is crashing. The logs show a `ModuleNotFoundError` for `config.wsgi_app`. That's the WSGI module gunicorn is trying to load. Let me check what command is being used."

### 3. Inspect the container command (~2 min)

```bash
kubectl get deploy incident-api -n incident-mgmt -o yaml | grep -A5 "command"
```

**Say:** "There's a `command` field in the container spec: `gunicorn config.wsgi_app:application`. That looks wrong. Let me check what the Dockerfile uses."

### 4. Compare with the Dockerfile (~1 min)

```bash
cat Dockerfile | grep CMD
```

**Say:** "The Dockerfile CMD uses `config.wsgi:application`, but the Deployment has a `command` override with `config.wsgi_app:application`. The underscore in `wsgi_app` is wrong -- the module is called `wsgi`, not `wsgi_app`. This `command` field in the Deployment is overriding the correct Dockerfile CMD with a wrong module path."

### 5. Verify the module exists (~30 sec)

```bash
ls config/
```

**Say:** "I can confirm: the config directory has `wsgi.py`, not `wsgi_app.py`. The command in the Deployment is referencing a module that doesn't exist."

### 6. Fix (~1 min)

The correct fix is to **remove the `command` field entirely** from the main container, since the Dockerfile CMD already has the correct command. Alternatively, fix the module name from `config.wsgi_app` to `config.wsgi`.

**Option A (preferred -- remove the unnecessary override):**

```bash
# Edit manifests/api-deployment.yaml and remove the command line from the incident-api container
vi manifests/api-deployment.yaml
# Delete the line: command: ["gunicorn", "config.wsgi_app:application", "--bind", "0.0.0.0:8200", "--workers", "2"]

kubectl apply -f manifests/api-deployment.yaml -n incident-mgmt
```

**Option B (fix the typo):**

```bash
sed -i 's/config.wsgi_app:application/config.wsgi:application/' manifests/api-deployment.yaml
kubectl apply -f manifests/api-deployment.yaml -n incident-mgmt
```

### 7. Verify end-to-end (~2 min)

```bash
# Wait for rollout
kubectl rollout status deploy/incident-api -n incident-mgmt --timeout=60s

# Check pods
kubectl get pods -n incident-mgmt

# Verify endpoints
curl http://localhost/
curl http://localhost/health
curl http://localhost/api/incidents/
```

**Say:** "The new pods are Running and Ready. All three endpoints are responding correctly. The issue was a `command` override in the Deployment manifest that referenced the wrong WSGI module. Removing it lets the container fall back to the Dockerfile CMD, which has the correct module path."

---

## Assessor Guidance

### What makes this tricky

- The `command` field in a Kubernetes container spec **overrides** the Dockerfile `CMD`. Candidates need to understand this Docker/Kubernetes interaction.
- Init containers complete successfully, which may lead candidates to think the pod startup is fine and look elsewhere.
- The error is a Python `ModuleNotFoundError`, which could initially suggest a missing dependency or broken image rather than a command override issue.
- The typo is subtle: `wsgi_app` vs `wsgi` -- candidates need to compare the command against the actual module structure.
- If old replicas are still running (rolling update), the app may partially work, making the symptom intermittent and harder to pin down.

### Common mistakes

- Focusing on init containers when they are completing fine.
- Assuming the image is broken and trying to rebuild it.
- Not checking `kubectl logs` for the main container (or checking only init container logs).
- Not comparing the manifest `command` with the Dockerfile `CMD`.
- Fixing the typo in the `command` field without questioning why the `command` override exists at all.
- Not verifying end-to-end after applying the fix.

### Red flags

- Never reading the container logs.
- Not understanding that `command` in a Kubernetes spec overrides the Dockerfile CMD.
- Trying to fix the Python module structure instead of the manifest.
- Deleting and recreating the entire Deployment instead of making a targeted fix.

---

## Evaluation Criteria

| Criterion | Needs Work | Solid | Strong |
|---|---|---|---|
| **Entry mode** | Jumped to random investigations without checking pod status | Checked pods, found CrashLoopBackOff, checked logs | Systematic: confirmed symptom, checked pods, immediately went to logs for crashing container |
| **Runtime flow** | Scattered commands with no clear sequence | Followed pods -> logs -> describe -> identify command -> fix | Efficient: symptom -> pods -> logs -> spotted ModuleNotFoundError -> traced to command override -> compared with Dockerfile -> fix |
| **Signal reading** | Missed the ModuleNotFoundError or the command override | Found the error in logs, identified the command override | Connected the dots: ModuleNotFoundError -> command field -> compared with Dockerfile CMD -> identified the wrong module name |
| **Hypothesis-driven** | Tried random fixes (rebuild image, restart pods) | Formed a theory about the command after reading logs | Articulated "The command field is overriding the Dockerfile CMD with a wrong module path" before fixing |
| **Intentional commands** | Ran commands without clear purpose | Each command had a reason | Could explain why each command was run and what they expected to see |
| **Smallest fix** | Deleted and recreated the Deployment, or rebuilt the image | Fixed the typo in the command field | Removed the unnecessary command override entirely, explaining that the Dockerfile CMD is correct |
| **End-to-end verification** | Stopped after applying the fix | Checked pods are Running | Verified rollout status, pod state, and all three endpoints (/, /health, /api/incidents/) |
| **Communication** | Silent debugging | Narrated key findings | Clear narration: "Init containers are fine, main container is crashing... the command references a module that doesn't exist... the Dockerfile has the correct command" |

---

## Hints (if candidate is stuck)

**Hint 1 (gentle direction):** "The pods seem to be crashing. Have you checked the container logs to see what error is occurring?"

**Hint 2 (more specific):** "The error message mentions a specific module. Does that module actually exist in the application?"

**Hint 3 (strong nudge):** "Compare the command that's running in the container with what the Dockerfile says should run. Where is the command being set?"

---

## Fix Summary

| What | Before (broken) | After (fixed) |
|---|---|---|
| `manifests/api-deployment.yaml` -> `incident-api` container | Has `command: ["gunicorn", "config.wsgi_app:application", ...]` overriding Dockerfile CMD | `command` field removed (Dockerfile CMD used) or typo fixed to `config.wsgi:application` |
| Main container | Crashes with `ModuleNotFoundError: No module named 'config.wsgi_app'` | Starts successfully with correct WSGI module |
| Pod status | `CrashLoopBackOff` | `Running` and `Ready` |
