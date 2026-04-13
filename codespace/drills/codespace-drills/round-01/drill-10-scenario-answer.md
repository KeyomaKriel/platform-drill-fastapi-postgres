# Drill 10 — Debugging Answer Key (Assessor Copy)

**App:** Django incident API (`drill-app-django`)
**Failure domain:** Probe Failure (Tier 1)
**Injected fault:** Both readiness and liveness probe paths changed from `/api/v1/status` (the real health endpoint) to `/health` (a path that returns 404). Readiness failure removes pods from Service endpoints. Liveness failure kills and restarts the container. The combination causes pods to cycle through Ready → not Ready → killed → restarted → briefly Ready again → repeat.

---

## What will happen after injection

- The Deployment triggers a rolling update with the new probe paths
- New pods start and initially pass probes briefly (Django may return a 200 on some paths during startup)
- Once the probes consistently hit `/health` (which returns 404), readiness fails first — pods become `0/1 Running`
- Endpoints empty out — no traffic reaches the pods through the Service
- Liveness probe also fails — kubelet kills the container, restart count climbs
- Pods cycle: Running 0/1 → killed → restarted → briefly 1/1 → fails again
- External curl returns 502 or times out intermittently (matches the "flapping" symptom)
- Old pods may linger briefly during the rolling update

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods `Running` but `0/1` Ready | `kubectl get pods` | Readiness probe failing |
| RESTARTS climbing | `kubectl get pods` | Liveness probe killing the container |
| `Readiness probe failed: HTTP probe failed with statuscode: 404` | `kubectl describe pod` Events | Probe path returns 404 |
| `Liveness probe failed: HTTP probe failed with statuscode: 404` | `kubectl describe pod` Events | Same wrong path on liveness |
| Probe path is `/health` | `kubectl describe pod` or `kubectl get deploy -o yaml` | Not a real endpoint |
| Manifest says `/api/v1/status` | `cat manifests/api-deployment.yaml` | Source of truth shows correct path |
| Endpoints empty or flapping | `kubectl get endpoints` | Readiness failure removes pods from endpoints |
| Port-forward to pod on 8200 → `/api/v1/status` returns 200 | `kubectl port-forward` | App is healthy, probe path is wrong |

---

## Ideal diagnostic path (~10-12 commands)

```bash
curl -i localhost/api/v1/status                                 # reproduce: 502 or timeout (intermittent)
kubectl get pods -n incident-mgmt                               # pods 0/1 Ready, RESTARTS climbing
kubectl describe pod <pod> -n incident-mgmt                     # Events: "Readiness probe failed: HTTP 404", "Liveness probe failed: HTTP 404"
kubectl get pod <pod> -n incident-mgmt -o jsonpath='{.spec.containers[0].readinessProbe.httpGet.path}'   # /health
kubectl port-forward pod/<pod> 8080:8200 -n incident-mgmt       # test what the app actually serves
# (in another terminal) curl -i localhost:8080/health            # 404
# (in another terminal) curl -i localhost:8080/api/v1/status     # 200
cat manifests/api-deployment.yaml                               # probes should target /api/v1/status
kubectl apply -f manifests/api-deployment.yaml                  # restore correct probe paths
kubectl rollout status deployment/incident-api -n incident-mgmt # wait for healthy rollout
kubectl get pods -n incident-mgmt                               # all 1/1 Ready, restarts stable
curl -i localhost/api/v1/status                                 # 200
curl -i localhost/api/v1/incidents                               # returns data
```

---

## Narration guide — what to say out loud at each stage

**After reproducing the symptom (502 or intermittent failure):**
> "The API is returning errors intermittently. That matches the reported flapping. Let me check pod state — flapping often means readiness or liveness probes are cycling."

**After `kubectl get pods` (0/1 Ready, restarts climbing):**
> "The pods are Running but not Ready, and restarts are climbing. That's a classic sign of probe failure — readiness is failing so the pod is removed from endpoints, and liveness is failing so kubelet keeps killing and restarting it. Let me check the probe configuration."

**After `kubectl describe pod` (see 404 on probes):**
> "The Events show both readiness and liveness probes failing with HTTP 404. The probe is hitting a path that returns 404. Let me check what path the probe is configured to use."

**After checking probe path (`/health`):**
> "The probes are targeting `/health`, but this is a Django app. Let me verify what the app actually responds to by port-forwarding to the pod directly."

**After port-forward testing (`/health` → 404, `/api/v1/status` → 200):**
> "The app responds 200 on `/api/v1/status` but 404 on `/health`. The probe path is wrong — it's hitting a path that doesn't exist. Let me check the manifest to see what the correct path should be."

**After `cat manifests/api-deployment.yaml` (probes target `/api/v1/status`):**
> "The manifest has both probes targeting `/api/v1/status`. The live deployment was changed to `/health`. I'll re-apply the manifest to restore the correct probe paths."

**After fix and verification:**
> "All pods are 1/1 Ready, restarts have stabilised, and both `/api/v1/status` and `/api/v1/incidents` return 200 through Ingress. The probes were targeting a path that doesn't exist in this app, causing both readiness and liveness to fail."

---

## What to watch for as assessor

### Good signs

- Connects "flapping" to probe failure immediately from the symptom description
- Reads `0/1 Ready` + `RESTARTS climbing` and narrows to probes before looking elsewhere
- Goes to `describe pod` Events and reads the probe failure messages (HTTP 404)
- Port-forwards to prove the app is healthy and the probe path is wrong
- Compares live probe config against manifest
- Uses `kubectl apply -f manifests/` to fix
- Verifies end-to-end after fix, including checking that restarts have stabilised

### Amber flags

- Fixes with `kubectl edit deploy` to correct probe paths — works but didn't use repo
- Doesn't port-forward to prove the app is healthy independently of the probes
- Fixes readiness but forgets about liveness (or vice versa)
- Doesn't explain the relationship between readiness → endpoints and liveness → restarts

### Red flags

- Doesn't check the probe spec despite seeing 0/1 Ready and restarts
- Blames the app for being unhealthy when it's the probe that's wrong
- Tries to fix the app rather than the probe configuration
- Doesn't understand why pods are being killed (liveness failure → kubelet restart)
- Can't explain the difference between readiness and liveness probes

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Checks ingress/services first despite "flapping" symptom | Checks pods, sees 0/1 + restarts | Connects "flapping" directly to probes, goes straight to pod state |
| 2 | **Runtime flow** | Random commands | Pods → describe → probe spec → fix | Curl → pods (0/1, restarts) → describe (404) → port-forward (app healthy) → manifest → apply → verify |
| 3 | **Signal reading** | Doesn't read probe failure events | Spots HTTP 404 in Events | Spots 404, identifies wrong path, AND proves correct path works via port-forward |
| 4 | **Hypothesis-driven** | Tries random fixes | "Probes are hitting the wrong path" | "The 0/1 Ready + restarts pattern means both probes are failing. The 404 tells me the path is wrong, not the app." |
| 5 | **Intentional commands** | 15+ commands | ~12 commands | ~10 commands, clean path |
| 6 | **Smallest fix** | Edits individual probe fields | kubectl edit to fix both probes | kubectl apply -f manifests/ (repo as source of truth, fixes both at once) |
| 7 | **End-to-end verification** | Declares fixed after pods Ready | Curls one endpoint | Curls both endpoints AND confirms restarts have stabilised |
| 8 | **Communication** | Silent | Narrates findings | Explains readiness → endpoints and liveness → restarts relationship clearly |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "Look at the pod status carefully — what do the READY column and RESTARTS tell you together?"

**Hint 2 (more specific):** "The Events section in describe pod will tell you exactly why the probes are failing."

**Hint 3 (pointed):** "The probe is getting a 404. What path is it hitting, and what path does the app actually serve its health check on?"
