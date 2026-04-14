# Drill 05 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Application dependency / runtime failure (Tier 2)
**Injected fault:** The `incident-db` Deployment was scaled to 0 replicas, removing all Postgres pods. The database service (`incident-db-svc`) still exists but has no backing endpoints. This causes: (1) the app's `/api/v1/status` health endpoint to return 503 (database unreachable), (2) readiness probes to fail (they hit `/api/v1/status`), (3) pods to be removed from Service endpoints, and (4) any new pod rollouts to hang at the `wait-for-db` init container (which runs `nc -z incident-db-svc 5432` in a loop).

---

## What will happen after injection

- The `incident-db` Deployment scales to 0 — all Postgres pods are terminated
- The `incident-db-svc` Service remains but `kubectl get endpoints incident-db-svc -n incident-mgmt` shows no addresses
- The existing `incident-api` pods are still Running, but the app can no longer reach Postgres
- The `/api/v1/status` health endpoint starts returning 503 because its DB connectivity check fails
- Since the readiness probe hits `/api/v1/status:8200`, the readiness probe now fails on existing pods
- Kubernetes marks existing pods as not Ready (`0/1 Running`) and removes them from the `incident-api-svc` endpoints
- Requests through Ingress return 502/503 because there are no Ready backends
- If the candidate tries to restart or delete app pods, new pods will get stuck at the `wait-for-db` init container (`Init:0/2`) because `nc -z incident-db-svc 5432` never succeeds
- `curl localhost/api/v1/status` returns 502/503 from Ingress (no healthy backends)
- `curl localhost/api/v1/incidents` also returns 502/503

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| App pods `0/1 Running` (not Ready) | `kubectl get pods -n incident-mgmt` | Pods are running but failing readiness checks |
| No Postgres pods visible | `kubectl get pods -n incident-mgmt` | The database deployment has no replicas |
| Readiness probe failing with 503 | `kubectl describe pod <app-pod> -n incident-mgmt` (Events) | The health endpoint is returning 503 — dependency failure |
| `incident-db` Deployment shows `0/0` replicas | `kubectl get deployments -n incident-mgmt` | Database deployment has been scaled to zero |
| `incident-db-svc` endpoints are empty | `kubectl get endpoints incident-db-svc -n incident-mgmt` | Service exists but no pods back it |
| `incident-api-svc` endpoints are empty | `kubectl get endpoints -n incident-mgmt` | App pods are not Ready, so they're removed from endpoints |
| App logs show database connection errors | `kubectl logs <app-pod> -n incident-mgmt` | App cannot connect to Postgres |
| Manifest shows `incident-db` should have replicas | `cat manifests/db-deployment.yaml` | Source of truth confirms the DB should be running |

---

## Ideal diagnostic path (~10-12 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # 502/503 — no healthy backends
curl localhost/api/v1/incidents                 # 502/503

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # app pods 0/1 Running, NO db pods visible

# 3. Check deployments to see the full picture
kubectl get deployments -n incident-mgmt        # incident-db shows 0/0 replicas

# 4. Describe an app pod to understand why it's not Ready
kubectl describe pod <app-pod> -n incident-mgmt
# Events: Readiness probe failed: HTTP probe failed with statuscode: 503

# 5. Check app logs for dependency errors
kubectl logs <app-pod> -n incident-mgmt         # database connection refused / unreachable errors

# 6. Check endpoints to confirm the Service routing picture
kubectl get endpoints -n incident-mgmt          # both services have no endpoints

# 7. Confirm with repo manifests — DB should be running
cat manifests/db-deployment.yaml                # replicas: 1 (or default)

# 8. Fix — reapply manifests to restore the DB deployment
kubectl apply -f manifests/ -n incident-mgmt

# 9. Wait for DB to come up
kubectl get pods -n incident-mgmt -w            # watch for db pod to become 1/1 Ready

# 10. Wait for app pods to recover readiness
kubectl get pods -n incident-mgmt               # app pods should return to 1/1 Ready once DB is reachable

# 11. End-to-end verification
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth and restores the DB deployment's replica count. `kubectl scale deployment/incident-db -n incident-mgmt --replicas=1` also works and is acceptable as a direct fix. The key insight is that the DB deployment was scaled to zero — the candidate needs to identify the missing database pods as the root cause, not just the app's readiness failure. If app pods were deleted during investigation, new ones may be stuck at `Init:0/2` (waiting for DB). Once the DB is restored, init containers will complete and pods will start normally. If `kubectl apply` doesn't resolve the drift, the fallback is:

```bash
kubectl replace -f manifests/db-deployment.yaml -n incident-mgmt
```

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "Both endpoints are returning errors. The app is completely down, not just degraded. Let me check what's happening at the pod level." |
| **After `get pods`** | "The app pods are Running but not Ready — 0/1. And I don't see any database pods at all. That's suspicious — the app depends on Postgres." |
| **After `get deployments`** | "The incident-db deployment is at 0/0 replicas. The database has been scaled down to zero. That explains why the app can't pass readiness — the health check probably tests database connectivity." |
| **After `describe pod`** | "The readiness probe is failing with 503, which confirms the app's health endpoint is reporting unhealthy because it can't reach the database." |
| **After checking manifests** | "The repo manifests define the DB deployment with replicas. It should be running. I'll reapply the manifests to restore everything to the expected state." |
| **After fix** | "The DB pod is starting up. Once it's Ready, the app pods should recover readiness automatically because the health endpoint will be able to reach Postgres again. Let me wait and verify." |

---

## What to watch for as assessor

### Good signs

- Notices both the app pods' readiness failure AND the missing database pods — connects the two
- Checks `get deployments` or notices the absence of DB pods early, doesn't tunnel-vision on the app pods
- Understands the causal chain: DB down -> health endpoint 503 -> readiness probe fails -> pods not Ready -> no endpoints -> 502
- Checks the app pod's readiness probe or logs to confirm it's a dependency issue, not an app bug
- Cross-references with manifests to confirm what the DB deployment should look like
- Uses `kubectl apply -f manifests/` to restore (repo as source of truth)
- Waits for the DB to be Ready before expecting app recovery
- Verifies end-to-end with both endpoints after fix
- Narrates the dependency chain clearly

### Amber flags

- Fixes with `kubectl scale deployment/incident-db --replicas=1` — works but doesn't demonstrate using the repo as source of truth
- Focuses only on the app pods' readiness failure without immediately noticing the missing DB pods
- Deletes/restarts app pods before fixing the DB (they'll just get stuck at init container)
- Identifies the DB is missing but doesn't explain WHY the app readiness is failing (the causal chain)
- Takes more than ~14 commands to reach the fix
- Doesn't explain what the readiness probe is checking and how it connects to the database

### Red flags

- Sees app pods `0/1 Running` and only investigates the app — never checks for the database
- Tries to fix readiness by changing the probe path or timing (the probe is correct; the dependency is missing)
- Focuses on Ingress or Service networking when the issue is a missing backend dependency
- Doesn't check `get deployments` or `get pods` broadly enough to notice the DB is gone
- Deletes app pods repeatedly hoping they'll self-heal
- Doesn't verify end-to-end after fixing
- Cannot explain why restoring the DB fixes the app's readiness

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps into app logs or Ingress config without broad pod/deployment check | Starts with get pods, notices app is not Ready | Reproduces symptom (curl), checks pods AND deployments, notices both the app readiness failure and missing DB |
| 2 | **Runtime flow** | Stuck investigating app probes or networking, misses the DB entirely | Pods → notices no DB → restores DB → verifies | Curl → get pods (0/1 Ready + no DB) → get deployments (0/0 replicas) → describe pod (503 readiness) → manifests → apply → verify. Clean causal chain. |
| 3 | **Signal reading** | Only sees app readiness failure, doesn't connect it to missing DB | Notices DB is gone, understands that's the root cause | Immediately connects 0/1 Ready + no DB pods + 503 readiness probe → dependency failure. Explains the full chain. |
| 4 | **Hypothesis-driven** | Tries fixing app probes or restarting pods randomly | "The DB is missing, that's why the app is unhealthy" | "App readiness is failing with 503, which means the health endpoint is reporting unhealthy. The DB deployment is at zero replicas — the app can't reach Postgres. The readiness probe is working correctly; it's the dependency that's broken." |
| 5 | **Intentional commands** | 16+ commands, long detour into app config or networking | ~12 commands, mostly on target | ~8-10 commands, no wasted steps — broad check, identify DB missing, confirm with describe/logs, check manifests, fix, verify |
| 6 | **Smallest fix** | Tries to fix the app probes or restart app pods | kubectl scale to restore DB replicas | kubectl apply -f manifests/ (repo as source of truth, restores all resources) |
| 7 | **End-to-end verification** | Declares fixed after DB pod starts | Checks app pods recover to 1/1 Ready | Waits for DB Ready, confirms app pods recover to 1/1, curls /api/v1/status AND /api/v1/incidents |
| 8 | **Communication** | Silent or describes only what they see without reasoning | Narrates the key finding (DB is down) and fix | Narrates the full dependency chain: DB scaled to zero → health endpoint 503 → readiness fails → endpoints removed → Ingress 502. Explains why restoring DB fixes everything. |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The app pods are running but not Ready. What could cause the health endpoint to start failing when it was working before?"

**Hint 2 (more specific):** "The app depends on more than just its own code to be healthy. Have you checked whether all the components the app needs are actually running?"

**Hint 3 (pointed):** "Look at all the deployments in the namespace. Is everything that should be running actually running?"
