# Drill 02 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Probe failure (Tier 1)
**Injected fault:** Both the readiness and liveness probe ports on the `incident-api` Deployment were changed from `8200` (the actual container port) to `3000` (a port nothing listens on). The probe path (`/api/v1/status`) and all other settings were left unchanged.

---

## What will happen after injection

- The deployment triggers a rolling update with the modified pod template
- New pods start and the app container runs normally on port 8200
- Both readiness and liveness probes attempt HTTP GET `/api/v1/status` on port 3000
- Port 3000 has no listener — probes get "connection refused" and fail immediately
- **Readiness probe failures:** Pods go `0/1 Running` (not Ready). Endpoints are removed from the Service. Traffic through Ingress gets no healthy backends, producing intermittent 502 errors
- **Liveness probe failures:** After `failureThreshold` consecutive failures, kubelet kills the container and restarts it. Restart count climbs steadily
- The rolling update may or may not complete depending on timing — old pods may be torn down while new pods never become Ready, leading to a period of zero healthy endpoints
- The symptom from outside is intermittent 502s and timeouts, matching the vague prompt

---

## Key signals the candidate should find

| Signal | Where | What it means |
|---|---|---|
| Pods `0/1 Running`, restart count climbing | `kubectl get pods -n incident-mgmt` | Container is running but not Ready; kubelet is restarting it |
| `Readiness probe failed: Get "http://...:3000/api/v1/status": dial tcp ...:3000: connect: connection refused` | `kubectl describe pod <pod> -n incident-mgmt` (Events) | Readiness probe is targeting the wrong port |
| `Liveness probe failed: Get "http://...:3000/api/v1/status": dial tcp ...:3000: connect: connection refused` | `kubectl describe pod <pod> -n incident-mgmt` (Events) | Liveness probe is also targeting the wrong port |
| Probe port is `3000`, container port is `8200` | `kubectl describe pod <pod> -n incident-mgmt` (Container spec) | Mismatch between probe port and actual listening port |
| Endpoints empty or flapping | `kubectl get endpoints -n incident-mgmt` | No Ready pods means no endpoints for the Service |
| Manifest shows probes should use port `8200` | `cat manifests/api-deployment.yaml` | Source of truth confirms the correct port |

---

## Ideal diagnostic path (~10 commands)

```bash
# 1. Orient — check namespace and pod state
kubectl get pods -n incident-mgmt
# See: pods 0/1 Running, restart count > 0 and climbing

# 2. Describe a failing pod to read events and container spec
kubectl describe pod <pod-name> -n incident-mgmt
# Look for: Readiness/Liveness probe failed events with "connection refused" on port 3000
# Look for: Container spec showing containerPort 8200 but probe port 3000

# 3. Confirm endpoints are affected
kubectl get endpoints -n incident-mgmt
# See: incident-api endpoints empty or missing addresses

# 4. (Optional) Verify the app is actually running inside the pod
kubectl exec -n incident-mgmt <pod-name> -- curl -s http://localhost:8200/api/v1/status
# Returns 200 — the app is healthy, the probes are just pointing at the wrong port

# 5. Compare with repo manifest (source of truth)
cat manifests/api-deployment.yaml
# Confirm probes should target port 8200, not 3000

# 6. Fix — reapply the correct manifest
kubectl apply -f manifests/api-deployment.yaml -n incident-mgmt

# 7. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 8. Verify pods are healthy
kubectl get pods -n incident-mgmt
# All pods 1/1 Running, restart count reset

# 9. Verify endpoints
kubectl get endpoints -n incident-mgmt
# incident-api has populated addresses

# 10. End-to-end verification
curl localhost/api/v1/status       # 200 healthy
curl localhost/api/v1/incidents    # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/api-deployment.yaml` is the preferred fix because it uses the repo manifest as source of truth. Since the fault replaces a scalar value (the port number), the three-way merge should work cleanly — `apply` will detect the drift from the last-applied annotation and restore port `8200`. If for any reason the merge doesn't take effect, the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

---

## Narration guide

| Stage | What the candidate should be saying |
|---|---|
| **After `get pods`** | "Both pods are showing 0/1 Running — the containers are running but they're not passing readiness checks. The restart count is climbing too, which means the liveness probe is also failing. That's why the API is intermittent — the endpoints keep flapping as pods cycle." |
| **After `describe pod`** | "The events show both readiness and liveness probes failing with 'connection refused' on port 3000. But the container port is 8200. The probes are targeting a port that nothing is listening on — that's the root cause." |
| **After checking endpoints** | "The endpoints are empty because no pods are Ready. That explains the 502s from the Ingress — there are no healthy backends to route to." |
| **After checking manifest** | "The repo manifest has the probes correctly pointing at port 8200. The live deployment has drifted — the probe ports were changed to 3000. I'll reapply the manifest to restore the correct configuration." |
| **After fix** | "Let me verify the rollout completes, pods become Ready, endpoints are populated, and then test the actual endpoints to confirm the API is fully operational." |

---

## What to watch for as assessor

### Good signs

- Notices `0/1 Running` and climbing restart count — connects this to probe failures, not app crashes
- Goes to `describe pod` and reads the Events section, finding the "connection refused" on port 3000
- Spots the mismatch: probes target port 3000, container listens on 8200
- Understands the cascading effect: probe failure -> not Ready -> no endpoints -> 502s from Ingress
- Checks the repo manifest to confirm the correct probe port
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with both `/api/v1/status` and `/api/v1/incidents`
- Narrates the distinction between readiness (not Ready, endpoints removed) and liveness (container restart)

### Amber flags

- Fixes with `kubectl edit` or `kubectl patch` to change the port back to 8200 — works but doesn't use repo as source of truth
- Doesn't check what port the container actually listens on
- Doesn't understand why the restart count is climbing (liveness vs readiness distinction)
- Checks logs first — logs will show the app running normally since the app itself is fine; may cause confusion
- Takes more than ~12 commands to reach the fix
- Fixes only one probe (readiness or liveness) but not both

### Red flags

- Doesn't recognise `0/1 Running` as a readiness probe failure — chases image, config, or networking issues
- Tries to delete pods or restart the deployment hoping it self-heals (the bad probe port is in the deployment spec)
- Sees "connection refused" and thinks the app is crashing or not starting
- Changes the container port to 3000 to match the probes (backwards fix)
- Doesn't verify end-to-end after fixing
- Can't explain why the API was intermittent — the mechanism of probe -> readiness -> endpoints -> Ingress routing

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|---|---|---|---|
| 1 | **Entry mode** | Jumps to logs or curls without checking pod state | Starts with get pods, notices 0/1 and restarts | Checks repo structure first to understand probes, then cluster state |
| 2 | **Runtime flow** | Random commands, no logical progression | Pods -> describe -> identify probe port mismatch -> fix | Pods -> describe -> verify app is running (exec curl) -> compare with manifest -> fix, tight path |
| 3 | **Signal reading** | Doesn't recognise 0/1 Running or "connection refused" as probe-related | Reads describe output and finds probe port mismatch | Immediately connects "connection refused on port 3000" to the wrong probe port and explains the cascading impact |
| 4 | **Hypothesis-driven** | Tries random things without stating why | "I think the probes are misconfigured, let me check" | "Pods are Running but not Ready and restarting — this points to both readiness and liveness probe failures. Let me check what port the probes are targeting." |
| 5 | **Intentional commands** | 15+ commands, detours into networking or config | ~10 commands, mostly on-target | ~7-8 commands, no wasted steps, each one building on the last |
| 6 | **Smallest fix** | Changes container port or rebuilds app | kubectl edit to fix probe ports | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods show 1/1 | Curls one endpoint | Curls /api/v1/status and /api/v1/incidents, checks endpoints are populated |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates throughout: explains the readiness/liveness distinction, the endpoint flapping, and the cascading effect on Ingress routing |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "Look at the pod status carefully — what does 0/1 in the Ready column tell you? And what about the restart count?"

**Hint 2 (more specific):** "The events on the pod mention something being refused. What is the pod trying to connect to, and on what port?"

**Hint 3 (pointed):** "Compare the port number in the probe configuration with the port the container is actually listening on."
