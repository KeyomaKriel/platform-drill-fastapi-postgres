# Drill 02 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Process startup / command failure (Tier 2)
**Injected fault:** The Deployment `incident-api` was patched to add `command: ["./incident-service"]` to the main container. This overrides the Dockerfile CMD (`gunicorn config.wsgi:application --bind 0.0.0.0:8200 --workers 2`) with a non-existent binary. The container fails immediately with `exec: "./incident-service": stat ./incident-service: no such file or directory`.

---

## What will happen after injection

- The patch triggers a rolling update. New pods are created with the overridden command.
- Init containers (`wait-for-db`, `run-migrations`) complete successfully — the command override only affects the main container.
- The main container crashes immediately on startup: the binary `./incident-service` does not exist in the image.
- Pod status cycles through `CrashLoopBackOff` / `Error`.
- Old replica(s) may be terminated once the rollout progresses (or the rollout may stall depending on `maxUnavailable`).
- `curl localhost/api/v1/status` returns 502/503 (no healthy backends).
- `kubectl logs` for the main container shows the exec error message.
- `kubectl describe pod` shows the container exiting with a non-zero exit code and the restart count climbing.

This fault tests whether the candidate can read container-level error signals and identify that the container command has been overridden away from what the Dockerfile specifies.

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pod status `CrashLoopBackOff` or `Error` | `kubectl get pods -n incident-mgmt` | Main container is failing to start |
| Init containers completed (0/1 Ready, init containers show Complete) | `kubectl describe pod -n incident-mgmt` | Problem is in the main container, not init containers |
| `exec: "./incident-service": stat ./incident-service: no such file or directory` | `kubectl logs <pod> -n incident-mgmt` | The container is trying to execute a binary that doesn't exist |
| `command: ["./incident-service"]` in the pod spec | `kubectl describe pod` or `kubectl get deployment -o yaml` | An explicit command override is present on the container |
| Dockerfile CMD is `gunicorn config.wsgi:application ...` | `cat Dockerfile` | The image's default entrypoint is gunicorn, not `./incident-service` |
| Manifest has no `command:` field | `cat manifests/api-deployment.yaml` | The repo source of truth does not include this command override |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # 502/503 — confirms the problem

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # CrashLoopBackOff — main container failing

# 3. Check logs for the crashing container
kubectl logs <pod> -n incident-mgmt             # "exec: ./incident-service: no such file or directory"

# 4. Describe the pod to see the command override
kubectl describe pod <pod> -n incident-mgmt
# Look for: Command: ["./incident-service"] on the main container

# 5. Check the Dockerfile to see what the image actually runs
cat Dockerfile                                  # CMD gunicorn config.wsgi:application --bind 0.0.0.0:8200 --workers 2

# 6. Check the repo manifest (source of truth)
cat manifests/api-deployment.yaml               # No command field — confirms the override is a drift

# 7. Fix — reapply the correct manifest to remove the command override
kubectl apply -f manifests/ -n incident-mgmt

# 8. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt

# 9. Verify pods are healthy
kubectl get pods -n incident-mgmt               # Running, Ready

# 10. End-to-end verification
curl localhost/                                 # app info
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth and removes the command override. If the candidate uses `kubectl edit` or `kubectl patch` to remove the `command` field, that works but doesn't use the repo as source of truth. If the candidate tries to fix by changing the command to the correct gunicorn invocation, that works but is fragile — the Dockerfile already has the correct CMD.

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "I'm getting a 502. The Ingress can't reach the backend. Let me check the pods." |
| **After `get pods`** | "The pods are in CrashLoopBackOff. The main container is crashing. Let me check the logs." |
| **After `logs`** | "The error is 'exec: ./incident-service: no such file or directory'. The container is trying to run a binary called `incident-service` that doesn't exist in the image. This looks like a command override issue." |
| **After `describe pod`** | "I can see `Command: [./incident-service]` on the main container. This is overriding the Dockerfile's CMD. Let me check what the image actually runs." |
| **After checking Dockerfile** | "The Dockerfile CMD is `gunicorn config.wsgi:application --bind 0.0.0.0:8200 --workers 2`. Someone added a command override that replaces this with a non-existent binary." |
| **After checking manifest** | "The deployment manifest doesn't have a `command` field, so this override was applied directly to the cluster. I'll reapply the manifest to remove it." |
| **After fix** | "Pods are coming up healthy. Let me verify all endpoints return expected responses." |

---

## What to watch for as assessor

### Good signs

- Checks pod status early and identifies CrashLoopBackOff
- Reads container logs and spots the exec error immediately
- Connects the error to a command/entrypoint override rather than a missing binary in the image build
- Inspects the pod spec to find the `command` field
- Cross-references with both the Dockerfile and the deployment manifest
- Understands the Kubernetes command/args vs Dockerfile CMD/ENTRYPOINT relationship
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end after fix
- Narrates: "There's a command override on the container that replaces the Dockerfile CMD with a non-existent binary"

### Amber flags

- Fixes with `kubectl edit` to remove the command field — works but doesn't use the repo
- Fixes by setting the command to the correct gunicorn invocation — works but is fragile
- Checks logs but doesn't explain *why* the wrong binary is being executed
- Doesn't check the Dockerfile to understand what the image should actually run
- Takes more than ~12 commands to reach the fix

### Red flags

- Sees CrashLoopBackOff and immediately tries to restart the pod or delete it
- Tries to rebuild the image with `./incident-service` included
- Focuses on init containers even though they completed successfully
- Doesn't read the logs at all
- Can't explain the difference between a Dockerfile CMD and a Kubernetes `command` override
- Doesn't verify end-to-end after fixing

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to describe/edit without checking symptoms | Starts with curl, then get pods | Reproduces symptom, checks pods, goes straight to logs |
| 2 | **Runtime flow** | Random commands, stuck on init containers or networking | Pods → logs → identifies exec error → fix | Curl → pods (CrashLoopBackOff) → logs (exec error) → describe (command override) → Dockerfile (correct CMD) → manifest (no command) → fix, clean progression |
| 3 | **Signal reading** | Misses the exec error in logs or doesn't check logs | Spots exec error, investigates further | Immediately connects exec error to a command override, checks both Dockerfile and pod spec |
| 4 | **Hypothesis-driven** | Tries random fixes (restart, rebuild) | "There's a wrong binary, let me check why" | "The container has a command override replacing the Dockerfile CMD. The manifest doesn't have this, so it's cluster drift." |
| 5 | **Intentional commands** | 15+ commands, detours into networking/services | ~10 commands, mostly on target | ~8 commands, no wasted steps — logs reveal the issue, describe confirms, manifest provides the fix |
| 6 | **Smallest fix** | Rebuilds image or sets command to gunicorn explicitly | kubectl edit to remove command field | kubectl apply -f manifests/ (repo as source of truth, removes the override) |
| 7 | **End-to-end verification** | Declares fixed after pods are Running | Curls one endpoint | Curls /, /api/v1/status, and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates throughout: symptom, CrashLoopBackOff, exec error, command override, Dockerfile CMD, drift from manifest, fix rationale |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods are crashing. Have you checked what's in the container logs?"

**Hint 2 (more specific):** "The error mentions a specific binary. Where does the container get its startup command from?"

**Hint 3 (pointed):** "Compare what the pod spec says for `command` with what the Dockerfile has for `CMD`. Are they the same?"
