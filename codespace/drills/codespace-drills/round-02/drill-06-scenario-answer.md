# Drill 06 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Startup / crash failure — process command (Tier 2)
**Injected fault:** A `command` field was added to the main container in the `incident-api` Deployment via JSON patch. The command overrides the Dockerfile CMD and sets gunicorn to load `config.wsgi_broken:application` — a module that does not exist. Gunicorn fails with `ModuleNotFoundError` and exits immediately, causing `CrashLoopBackOff`.

---

## What will happen after injection

- The `kubectl patch` adds a `command` field to the `incident-api` container: `["gunicorn", "config.wsgi_broken:application", "--bind", "0.0.0.0:8200", "--workers", "2"]`
- This overrides the Dockerfile CMD (`config.wsgi:application` — the correct module path)
- A rolling update begins. New pods pass through init containers (wait-for-db and run-migrations) successfully, since those use their own `command` fields
- When the main container starts, gunicorn tries to import `config.wsgi_broken` — the module does not exist
- Gunicorn logs `ModuleNotFoundError: No module named 'config.wsgi_broken'` and exits with a non-zero code
- The container enters `CrashLoopBackOff` — it starts, fails, restarts with exponential backoff
- Old pods are preserved by the rolling update strategy because new pods never become Ready
- Depending on timing and `maxUnavailable`, the app may still be partially reachable via old pods, or may return 502/503
- `kubectl describe pod` on a new pod will show restart count increasing and `CrashLoopBackOff` status
- `kubectl logs` on a new pod will show the gunicorn import error

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| New pods in `CrashLoopBackOff` | `kubectl get pods -n incident-mgmt` | Container is crashing repeatedly on startup |
| Old pods still `1/1 Running` | `kubectl get pods -n incident-mgmt` | Rolling update stalled — old pods preserved |
| `ModuleNotFoundError: No module named 'config.wsgi_broken'` | `kubectl logs <new-pod> -n incident-mgmt` | Gunicorn is trying to load a non-existent module |
| Container has explicit `command` field | `kubectl describe pod <new-pod> -n incident-mgmt` | The container spec shows a command override that differs from the Dockerfile CMD |
| Command references `config.wsgi_broken:application` | `kubectl describe pod <new-pod>` or `kubectl get deployment incident-api -n incident-mgmt -o yaml` | The WSGI module path is wrong — should be `config.wsgi:application` |
| Manifest has no `command` field on the main container | `cat manifests/api-deployment.yaml` | Source of truth shows the container should use the Dockerfile CMD (no command override) |
| Dockerfile CMD uses `config.wsgi:application` | `cat Dockerfile` | Confirms the correct module path |
| Restart count increasing | `kubectl describe pod <new-pod> -n incident-mgmt` | Container keeps crashing and restarting |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # may work (old pods) or 502
curl localhost/api/v1/incidents                 # same

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # new pods in CrashLoopBackOff, old pods 1/1

# 3. Check logs on a crashing pod
kubectl logs <new-pod> -n incident-mgmt
# Shows: ModuleNotFoundError: No module named 'config.wsgi_broken'

# 4. Describe the pod to see the container spec
kubectl describe pod <new-pod> -n incident-mgmt
# Look for: Command: gunicorn config.wsgi_broken:application --bind 0.0.0.0:8200 --workers 2
# This is a command override that shouldn't be there

# 5. Compare with repo manifest (source of truth)
cat manifests/api-deployment.yaml               # no command field on the main container
cat Dockerfile                                  # CMD uses config.wsgi:application

# 6. Fix — reapply the correct manifest to remove the command override
kubectl apply -f manifests/ -n incident-mgmt

# 7. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 8. Verify pods
kubectl get pods -n incident-mgmt               # all pods 1/1 Running/Ready

# 9. End-to-end verification
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth and removes the spurious `command` override. `kubectl apply -f manifests/api-deployment.yaml` is equally correct. An alternative approach using `kubectl patch` to remove the command field works:

```bash
kubectl patch deployment/incident-api -n incident-mgmt --type=json -p '[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]'
```

Using `kubectl rollout undo deployment/incident-api -n incident-mgmt` also works but doesn't demonstrate using the repo as source of truth. If `kubectl apply` doesn't resolve the drift (annotation-based three-way merge edge case), the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

**Key insight:** The candidate needs to understand the relationship between a Dockerfile CMD and a Kubernetes `command` field override. When a `command` is specified in the pod spec, it completely replaces the Dockerfile CMD. The fix is to remove the command override so the container falls back to the Dockerfile CMD.

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "The API is down or intermittent. Let me check the pods." |
| **After `get pods`** | "I can see pods in CrashLoopBackOff — they're crashing and restarting. The old pods are still running, so this looks like a rolling update that's stalled. Let me check the logs to see why the new pods are crashing." |
| **After `logs`** | "There's a ModuleNotFoundError — gunicorn is trying to load `config.wsgi_broken` which doesn't exist. That module path looks wrong. Let me check the pod spec to see where this command is coming from." |
| **After `describe pod`** | "The container has an explicit `command` field overriding the Dockerfile CMD. It's set to use `config.wsgi_broken:application` instead of `config.wsgi:application`. This command override shouldn't be there." |
| **After checking manifests** | "The repo manifest doesn't have a `command` field on the main container — it relies on the Dockerfile CMD which uses the correct path `config.wsgi:application`. Someone or something added a command override with a typo. I'll reapply the manifests to remove it." |
| **After fix** | "The rollout is progressing. New pods should now use the Dockerfile CMD with the correct module path. Let me wait and verify." |

---

## What to watch for as assessor

### Good signs

- Goes to `kubectl logs` early when seeing CrashLoopBackOff — that's the primary signal source for crash failures
- Reads the error message carefully and identifies `config.wsgi_broken` as the wrong module path
- Uses `describe pod` to find the `command` override and understands it overrides the Dockerfile CMD
- Cross-references with the manifest (no command field) and/or Dockerfile (correct CMD) to confirm the drift
- Understands the CMD vs command override relationship in Kubernetes
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with all endpoints after fix
- Narrates the causal chain: command override -> wrong module -> import error -> crash -> CrashLoopBackOff

### Amber flags

- Fixes with `kubectl rollout undo` — works but doesn't demonstrate understanding of what changed
- Reads the logs and identifies the wrong module but doesn't investigate WHY gunicorn is using the wrong module (doesn't check for command override)
- Tries to fix by editing the Dockerfile and rebuilding the image (the Dockerfile is correct)
- Takes a long path through services, networking, or probes before checking logs
- Doesn't explain the CMD vs command override relationship
- Takes more than ~12 commands to reach the fix

### Red flags

- Sees CrashLoopBackOff but doesn't check logs — the most direct signal for crash failures
- Reads the error but doesn't understand what `ModuleNotFoundError` means — investigates networking instead
- Tries to create the missing module `config/wsgi_broken.py` (fixing the wrong thing — the module path is wrong, not missing)
- Focuses on init containers, probes, or services when the main container is crash-looping
- Doesn't check the pod spec to see the command override — tries to fix the Dockerfile or rebuild
- Deletes pods repeatedly hoping they'll self-heal
- Doesn't verify end-to-end after fixing
- Cannot explain the difference between Dockerfile CMD and Kubernetes command override

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to networking or services without checking pod status and logs | Starts with get pods, notices CrashLoopBackOff | Reproduces symptom (curl), checks pods, immediately identifies crash-looping pods and goes to logs |
| 2 | **Runtime flow** | Random commands, stuck investigating probes or services | Pods -> logs -> identifies wrong module -> fix | Curl -> pods (CrashLoopBackOff) -> logs (ModuleNotFoundError) -> describe (command override) -> manifest/Dockerfile comparison -> fix -> verify. Clean path. |
| 3 | **Signal reading** | Doesn't check logs, or reads error but doesn't understand it | Spots the wrong module in logs, identifies it as the cause | Connects the full chain: command override in pod spec -> wrong WSGI module path -> gunicorn import failure -> crash. Understands CMD vs command. |
| 4 | **Hypothesis-driven** | Tries random restarts or investigates networking | "The module path is wrong, let me check where it's defined" | "Gunicorn is crashing because it's trying to import a non-existent module. The pod spec has a command override that shouldn't be there — the manifest relies on the Dockerfile CMD. I need to remove this override." |
| 5 | **Intentional commands** | 14+ commands, detours into services/networking/Ingress | ~10 commands, mostly on target | ~7 commands, no wasted steps — pods, logs, describe, check manifest, fix, verify |
| 6 | **Smallest fix** | Tries to create the missing module or rebuild the image | kubectl patch to remove the command field | kubectl apply -f manifests/ (repo as source of truth, removes the spurious command override) |
| 7 | **End-to-end verification** | Declares fixed after pods stop crashing | Curls one endpoint | Curls /api/v1/status and /api/v1/incidents, checks all pods are 1/1 Ready |
| 8 | **Communication** | Silent or only describes pod status without reasoning about cause | Narrates the key finding (wrong module path) and fix | Narrates throughout: crash symptoms, import error, command override vs Dockerfile CMD, drift from manifest, fix rationale. Explains the override mechanism. |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods are crashing. What's the first thing you'd check to understand why a container is crashing on startup?"

**Hint 2 (more specific):** "The logs show an import error. Where is the startup command coming from — is it always what you'd expect from the Dockerfile?"

**Hint 3 (pointed):** "Compare the command that's actually running in the pod with what the Dockerfile and the deployment manifest define. Is there a difference?"
