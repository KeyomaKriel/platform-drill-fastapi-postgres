# Drill 05 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Probe failure (Tier 1)
**Injected fault:** Both the readiness and liveness probe paths on the `incident-api` Deployment were changed from `/api/v1/status` to `/status`. The Django app has no route at `/status`, so it returns 404 for every probe request. This causes readiness probes to fail (pods marked not Ready, removed from Service endpoints) and liveness probes to fail (pods killed and restarted). The result is pods cycling between `0/1 Running` and restarts, with intermittent availability as new pods briefly serve traffic before probes fail again.

---

## What will happen after injection

- The `kubectl patch` triggers a rolling update — new pods are created with the modified probe paths
- New pods start and the container begins serving traffic on port 8200
- The readiness probe sends `GET /status:8200` — Django returns 404 (no such URL pattern)
- Kubernetes marks the pod as not Ready (`0/1 Running`) and removes it from `incident-api-svc` endpoints
- The liveness probe also sends `GET /status:8200` — Django returns 404
- After the liveness `failureThreshold` is exceeded, Kubernetes kills the container and restarts it
- The pod enters a cycle: start -> briefly running -> readiness fails -> liveness fails -> restart
- `kubectl get pods` shows increasing restart counts and `0/1 Running` or `CrashLoopBackOff` depending on timing
- During brief windows when a new container has just started but probes haven't failed yet, requests may succeed — explaining the "erratic" symptom
- `curl localhost/api/v1/status` intermittently returns 200 or 502/503 depending on timing
- `curl localhost/api/v1/incidents` same intermittent behaviour
- Old ReplicaSet pods (with correct probes) are terminated by the rolling update

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods `0/1 Running` with restarts | `kubectl get pods -n incident-mgmt` | Pods are running but failing health checks and being restarted |
| Readiness probe failed: 404 | `kubectl describe pod <app-pod> -n incident-mgmt` (Events) | The readiness probe path is returning 404 — wrong path |
| Liveness probe failed: 404 | `kubectl describe pod <app-pod> -n incident-mgmt` (Events) | The liveness probe path is also returning 404 — wrong path |
| Probe path is `/status` | `kubectl describe pod <app-pod>` or `kubectl get deploy incident-api -n incident-mgmt -o yaml` | The probe is hitting `/status` instead of `/api/v1/status` |
| App actually responds on `/api/v1/status` | `kubectl exec <pod> -n incident-mgmt -- curl -s localhost:8200/api/v1/status` | The app is healthy — the probe path is wrong, not the app |
| Manifest shows `/api/v1/status` | `cat manifests/app-deployment.yaml` | Source of truth has the correct probe path — live config has drifted |
| `incident-api-svc` endpoints empty or flickering | `kubectl get endpoints -n incident-mgmt` | No Ready pods to back the Service |
| Container is being killed (liveness) | Pod events in `describe` | Liveness failure causes container restart, not just readiness removal |

---

## Ideal diagnostic path (~10-12 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # intermittent 200 or 502/503
curl localhost/api/v1/incidents                 # same intermittent behaviour

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # app pods 0/1 Running, restart count increasing

# 3. Describe a pod to see WHY it's not Ready and restarting
kubectl describe pod <app-pod> -n incident-mgmt
# Events: Readiness probe failed: HTTP probe failed with statuscode: 404
# Events: Liveness probe failed: HTTP probe failed with statuscode: 404
# Probe config shows: httpGet path: /status, port: 8200

# 4. Verify the app itself is healthy (probe path is wrong, not the app)
kubectl exec <app-pod> -n incident-mgmt -- curl -s localhost:8200/api/v1/status
# 200 OK — app is fine

# 5. Compare live probe config with repo manifests
cat manifests/app-deployment.yaml               # probes point to /api/v1/status
kubectl get deploy incident-api -n incident-mgmt -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}'
# Returns: /status (should be /api/v1/status)

# 6. Fix — reapply manifests to restore correct probe paths
kubectl apply -f manifests/ -n incident-mgmt

# 7. Wait for rollout to complete with corrected probes
kubectl rollout status deployment/incident-api -n incident-mgmt

# 8. End-to-end verification
kubectl get pods -n incident-mgmt               # all pods 1/1 Running, no restarts on new pods
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth and restores the correct probe paths. An alternative is to patch the probes back directly:

```bash
kubectl patch deployment incident-api -n incident-mgmt --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/api/v1/status"},{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path","value":"/api/v1/status"}]'
```

This also works but doesn't demonstrate using the repo as source of truth. The key insight is that the probe paths have drifted from the manifests — the app is healthy, the probes are pointing to the wrong path.

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "It's intermittent — sometimes I get a response, sometimes 502. That pattern suggests something is flapping rather than completely down. Let me check the pods." |
| **After `get pods`** | "The app pods are 0/1 Running and the restart count is climbing. That means both readiness AND liveness probes are probably failing — readiness makes it not Ready, liveness is killing it. Let me check the events." |
| **After `describe pod`** | "Both probes are failing with 404. The probe path is `/status` but looking at the app, the actual health endpoint is at `/api/v1/status`. The probe is hitting a path that doesn't exist in the Django app." |
| **After exec curl** | "The app itself is fine — `curl localhost:8200/api/v1/status` inside the pod returns 200. So the application is healthy, the probe configuration is just pointing to the wrong path." |
| **After checking manifests** | "The manifests in the repo have the correct path `/api/v1/status`. The live deployment has drifted — someone or something changed the probe path to `/status`. I'll reapply the manifests to restore the correct configuration." |
| **After fix** | "The rollout is progressing with the corrected probe paths. New pods should pass both readiness and liveness checks. Let me wait for the rollout to finish and verify end-to-end." |

---

## What to watch for as assessor

### Good signs

- Notices the intermittent pattern and connects it to pods cycling (readiness/liveness flapping)
- Goes straight to `describe pod` to check probe events after seeing restart counts
- Reads the 404 status code in probe failure events and recognises it means wrong path, not app failure
- Distinguishes between "app is broken" and "probe is misconfigured" — tests the app directly with `kubectl exec`
- Compares live probe config against the repo manifests to identify the drift
- Uses `kubectl apply -f manifests/` to restore (repo as source of truth)
- Waits for rollout to complete before declaring fixed
- Verifies end-to-end with both endpoints after fix
- Explains why both readiness AND liveness failing causes the cycling behaviour

### Amber flags

- Fixes with a direct `kubectl patch` to correct the paths — works but doesn't use repo as source of truth
- Identifies the probe failure but doesn't explain the full impact (readiness removes from endpoints, liveness kills the container, together they cause the cycling)
- Takes more than ~14 commands to reach the fix
- Doesn't test the app directly inside the pod to confirm the app is healthy
- Doesn't explicitly compare live config with repo manifests

### Red flags

- Sees 404 in probe failures and tries to fix the Django app (add a `/status` route)
- Focuses on Ingress, Service, or networking when the issue is probe configuration
- Tries to fix by adjusting probe timing (increase timeouts/thresholds) rather than fixing the path
- Deletes pods repeatedly hoping they'll self-heal
- Doesn't read `describe pod` events — misses the 404 signal entirely
- Doesn't verify end-to-end after fixing
- Cannot explain what probes do or why wrong probe paths cause this behaviour

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps into app logs or Ingress config without checking pod state and events | Starts with get pods, notices restarts, checks describe | Reproduces symptom (curl — notices intermittent), checks pods (sees restarts), immediately goes to describe for events |
| 2 | **Runtime flow** | Stuck investigating app code or networking, misses probe config entirely | Pods → describe → sees probe failure → fixes | Curl (intermittent) → get pods (restarts) → describe (404 on probes) → exec curl (app healthy) → compare with manifests (drift) → apply → rollout status → verify. Clean causal chain. |
| 3 | **Signal reading** | Sees restarts but doesn't check probe events, or misinterprets 404 as app failure | Notices 404 probe failures, understands the path is wrong | Immediately connects 404 + probe path `/status` → wrong path. Verifies app is healthy at `/api/v1/status`. Identifies config drift from manifests. |
| 4 | **Hypothesis-driven** | Tries restarting pods or changing app code randomly | "The probes are hitting the wrong path, that's why they're failing" | "Probes are returning 404, which means the path doesn't exist in the app. The live config shows `/status` but the app serves health at `/api/v1/status` and the manifests confirm that's the correct path. This is config drift — the probes were changed." |
| 5 | **Intentional commands** | 16+ commands, long detour into logs/networking/Ingress | ~12 commands, mostly on target | ~8-10 commands, no wasted steps — get pods, describe, exec test, compare manifests, fix, verify |
| 6 | **Smallest fix** | Tries to add a `/status` route to Django or adjust probe timing | Patches the probe paths back to `/api/v1/status` | `kubectl apply -f manifests/` (repo as source of truth, restores correct probe config) |
| 7 | **End-to-end verification** | Declares fixed after apply without waiting for rollout | Checks pods are 1/1 Ready | Waits for rollout complete, confirms pods 1/1 with zero restarts on new pods, curls `/api/v1/status` AND `/api/v1/incidents` |
| 8 | **Communication** | Silent or describes only what they see without reasoning | Narrates the key finding (wrong probe path) and fix | Narrates the full chain: probe path changed → 404 → readiness fails (removed from endpoints) + liveness fails (container killed) → pods cycle → intermittent availability. Explains why restoring the correct path fixes everything. |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods seem to be cycling. What could cause a pod to keep restarting even though the application code hasn't changed?"

**Hint 2 (more specific):** "Look closely at the events on the pod. What status code are the probes getting back, and what does that specific code mean?"

**Hint 3 (pointed):** "Compare the probe configuration in the running pod with what the repo manifests define. Do the paths match?"
