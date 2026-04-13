# Drill 03 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Probe failure (Tier 1)
**Injected fault:** The readiness probe path on the `incident-api` Deployment's main container was changed from `/api/v1/status` to `/api/v1/ready` — a path that does not exist in the Django app. The endpoint returns 404, so the readiness probe fails and Kubernetes marks the new pods as not Ready.

---

## What will happen after injection

- The deployment triggers a rolling update with the modified pod template
- New pods start successfully — the app container runs, init containers complete, the liveness probe (still pointing at `/api/v1/status`) passes
- However, the readiness probe hits `/api/v1/ready` which returns 404, so the readiness check fails repeatedly
- Pods show `0/1 Running` (Running but not Ready) — the `READY` column shows `0/1`
- Because the new pods never become Ready, the rolling update stalls — it cannot proceed (new pods aren't Ready) and old pods are preserved by the rollout strategy
- Depending on timing, the user may see a mix of old pods (1/1 Ready) and new pods (0/1 Running, not Ready)
- The Service endpoints will include old Ready pods but exclude new not-Ready pods
- The app may still be partially reachable via old pods, or may return 502/503 intermittently if old pods have been scaled down
- `kubectl describe pod` on a new pod will show readiness probe failure events: `Readiness probe failed: HTTP probe failed with statuscode: 404`

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| New pods `0/1 Running` (not Ready) | `kubectl get pods -n incident-mgmt` | Container is running but failing readiness checks |
| Old pods still `1/1 Running` | `kubectl get pods -n incident-mgmt` | Rolling update preserves old pods because new ones aren't Ready |
| `Readiness probe failed: HTTP probe failed with statuscode: 404` | `kubectl describe pod <new-pod> -n incident-mgmt` (Events) | The readiness probe path returns 404 — endpoint doesn't exist |
| Readiness probe path is `/api/v1/ready` | `kubectl describe pod <new-pod> -n incident-mgmt` (Container spec) | Not the correct health endpoint |
| Liveness probe path is `/api/v1/status` | `kubectl describe pod <new-pod> -n incident-mgmt` (Container spec) | Liveness uses a different (correct) path — highlights the mismatch |
| Manifest says readiness path `/api/v1/status` | `cat manifests/api-deployment.yaml` | Source of truth shows the correct readiness probe path |
| Rollout is stalled | `kubectl rollout status deployment/incident-api -n incident-mgmt` | Waiting for new pods to become Ready |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # may work (old pods) or 502 (if old pods gone)

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # spot new pods 0/1 Running (not Ready), old pods 1/1

# 3. Describe the failing pod to read events and spec
kubectl describe pod <new-pod> -n incident-mgmt
# Look for: Events showing 'Readiness probe failed: HTTP probe failed with statuscode: 404'
# Look for: Readiness probe httpGet path is /api/v1/ready
# Notice:  Liveness probe httpGet path is /api/v1/status (different — correct one)

# 4. (Optional) Verify the probe endpoint doesn't exist
kubectl exec <new-pod> -n incident-mgmt -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8200/api/v1/ready
# Returns 404

# 5. Compare with repo manifest (source of truth)
cat manifests/api-deployment.yaml               # readinessProbe path should be /api/v1/status

# 6. Fix — reapply the correct manifest
kubectl apply -f manifests/ -n incident-mgmt

# 7. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 8. Verify pods
kubectl get pods -n incident-mgmt               # all 1/1 Running/Ready

# 9. End-to-end verification
curl localhost/                                 # app info
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth. If the candidate applies just the deployment manifest (`kubectl apply -f manifests/api-deployment.yaml`), that's equally correct. An alternative fix using `kubectl patch` or `kubectl edit` to restore the readiness probe path works but doesn't use the repo as source of truth. If `kubectl apply` doesn't resolve the drift (annotation-based three-way merge edge case), the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "I'm getting intermittent errors — sometimes it works, sometimes 502. That suggests some backends are healthy and some aren't. Let me check pod state." |
| **After `get pods`** | "I can see new pods that are Running but not Ready — `0/1`. The old pods are still `1/1` Ready. This looks like a rolling update where the new pods aren't passing readiness checks, so the rollout is stuck." |
| **After `describe pod`** | "The events show the readiness probe is failing with a 404. The probe is hitting `/api/v1/ready` but that endpoint doesn't exist. The liveness probe points to `/api/v1/status` which is correct — so only the readiness probe path was changed." |
| **After checking manifest** | "The repo manifest has both probes pointing at `/api/v1/status`. The live deployment has the readiness probe path changed to `/api/v1/ready` — that's the drift. I'll reapply the manifest to restore the correct probe configuration." |
| **After fix** | "The rollout is proceeding now. Let me wait for it to complete and then verify all three endpoints." |

---

## What to watch for as assessor

### Good signs

- Notices pods are Running but not Ready (`0/1`) — distinguishes this from CrashLoopBackOff or other crash states
- Goes to `describe pod` and reads the Events section carefully
- Spots the readiness probe failure with 404 status code
- Connects the 404 to a wrong probe path (not an app crash or networking issue)
- Notices the liveness probe has a different (correct) path — recognises the mismatch as the clue
- Cross-references with the repo manifest to confirm the correct probe path
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with all three endpoints after fix
- Narrates clearly: "The readiness probe is hitting a path that doesn't exist — the app is running fine but Kubernetes thinks it's not ready"

### Amber flags

- Fixes with `kubectl edit` or `kubectl patch` to correct the probe path — works but doesn't use the repo as source of truth
- Spends time investigating why the app might be returning 404 on `/api/v1/ready` (looking at Django URL routes, etc.) — correct instinct but unnecessary for the fix
- Checks logs expecting to find errors (the app itself is healthy — logs may not show probe failures clearly)
- Doesn't distinguish between readiness and liveness probes — treats probes as one thing
- Takes more than ~12 commands to reach the fix

### Red flags

- Sees `0/1 Running` and misinterprets it as a crash — tries to check for OOMKilled or crash loops
- Doesn't check `describe pod` events — misses the readiness probe failure entirely
- Tries to create the `/api/v1/ready` endpoint in the app code (fixing the wrong side)
- Restarts or deletes pods hoping they self-heal (the new pods will fail the same way)
- Focuses on networking or Service issues when the pods aren't Ready
- Doesn't verify end-to-end after fixing
- Can't explain the difference between readiness and liveness probes or why only readiness caused this symptom

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to logs or config without checking pod status | Starts with get pods, notices the Ready column | Reproduces symptom (curl), checks pods, immediately focuses on the 0/1 Ready discrepancy |
| 2 | **Runtime flow** | Random commands, stuck investigating app code or networking | Pods → describe → identifies probe failure → fix | Curl → pods (0/1 Ready) → describe (probe 404) → compare probes → check manifest → fix, tight path |
| 3 | **Signal reading** | Doesn't notice 0/1 Ready, or checks but misses probe events in describe | Spots readiness probe failure in events | Immediately connects 0/1 Running to readiness probe failure, notices liveness uses a different (correct) path |
| 4 | **Hypothesis-driven** | Tries random restarts or investigates networking | "Pods aren't Ready, let me check the readiness probe" | "0/1 Running means the container is up but failing readiness. The probe path returns 404 — this endpoint doesn't exist. Let me check what the path should be." |
| 5 | **Intentional commands** | 15+ commands, detours into logs/networking/Ingress | ~10 commands, mostly on target | ~8 commands, no wasted steps — straight to describe, spots the probe, checks manifest, fixes |
| 6 | **Smallest fix** | Creates a `/api/v1/ready` endpoint in the app | kubectl edit/patch to fix the probe path | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods show 1/1 | Curls one endpoint | Curls /, /api/v1/status, and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings and decisions | Narrates throughout: symptom observation, 0/1 Ready meaning, probe failure explanation, readiness vs liveness distinction, root cause, fix rationale |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "Look carefully at the pod status — are the pods fully healthy, or is there something off about their readiness?"

**Hint 2 (more specific):** "The pods are running but something is preventing Kubernetes from considering them ready to receive traffic. What controls that decision?"

**Hint 3 (pointed):** "Check the events on one of the new pods. What is the readiness probe actually checking, and does that endpoint exist?"
