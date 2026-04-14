# Drill 03 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Config / Secret / env failure (Tier 1)
**Injected fault:** The `POSTGRES_HOST` value in ConfigMap `incident-api-config` was changed from `incident-db-svc` to `incident-database` (a hostname that doesn't resolve). The deployment was then restarted so pods pick up the new ConfigMap value.

---

## What will happen after injection

- The deployment triggers a rolling update with restarted pods
- New pods start their init container sequence:
  1. **`wait-for-db` init container** — uses a hardcoded `nc -z incident-db-svc 5432` command, so it still connects to the correct hostname and **passes successfully**
  2. **`run-migrations` init container** — reads database config from the ConfigMap via `envFrom`, so it picks up `POSTGRES_HOST=incident-database` and tries to connect to that hostname
- `incident-database` does not resolve (no Service with that name exists), so the migration container fails with a DNS resolution or connection error
- Pods get stuck at `Init:1/2` — first init container completes, second init container fails repeatedly
- The main app container never starts
- Old pods are terminated by the rollout restart, so the service has no Ready endpoints
- `curl localhost/api/v1/status` returns 502/503

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods stuck at `Init:1/2` | `kubectl get pods -n incident-mgmt` | First init container passed, second is failing |
| `run-migrations` container in `CrashLoopBackOff` or `Error` | `kubectl describe pod <pod> -n incident-mgmt` | The migration init container is crashing |
| Connection error to `incident-database` in migration logs | `kubectl logs <pod> -n incident-mgmt -c run-migrations` | The migration container can't resolve/connect to the DB hostname |
| `POSTGRES_HOST=incident-database` in ConfigMap | `kubectl get configmap incident-api-config -n incident-mgmt -o yaml` | The hostname was changed from the correct `incident-db-svc` |
| Postgres Service is named `incident-db-svc` | `kubectl get svc -n incident-mgmt` | The actual DB service hostname is `incident-db-svc`, not `incident-database` |
| `wait-for-db` uses hardcoded `incident-db-svc` | `kubectl describe pod <pod>` or repo manifest | Explains why the first init container passes despite the bad ConfigMap value |
| Manifest shows `POSTGRES_HOST=incident-db-svc` | `cat manifests/api-configmap.yaml` or equivalent | Source of truth has the correct value |

---

## Ideal diagnostic path (~10-12 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # 502/503 — app is down

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # pods stuck at Init:1/2

# 3. Describe the failing pod
kubectl describe pod <pod> -n incident-mgmt
# Look for: Init container statuses — wait-for-db completed, run-migrations failing
# Look for: Events showing init container crash/restart

# 4. Check migration init container logs
kubectl logs <pod> -n incident-mgmt -c run-migrations
# Shows connection error: can't connect to host 'incident-database'

# 5. Check where the hostname comes from — inspect the ConfigMap
kubectl get configmap incident-api-config -n incident-mgmt -o yaml
# Shows POSTGRES_HOST: incident-database

# 6. Check what the DB Service is actually called
kubectl get svc -n incident-mgmt
# Shows the Postgres service is named incident-db-svc

# 7. Compare with repo manifest
cat manifests/api-configmap.yaml                # POSTGRES_HOST should be incident-db-svc

# 8. Fix — patch the ConfigMap back to the correct value
kubectl apply -f manifests/ -n incident-mgmt
# OR: kubectl patch configmap incident-api-config -n incident-mgmt -p '{"data":{"POSTGRES_HOST":"incident-db-svc"}}'

# 9. Restart the deployment to pick up the fix
kubectl rollout restart deploy/incident-api -n incident-mgmt

# 10. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=120s

# 11. Verify pods
kubectl get pods -n incident-mgmt               # all pods Running/Ready

# 12. End-to-end verification
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** The preferred fix is `kubectl apply -f manifests/` which restores the ConfigMap from the repo source of truth, followed by a rollout restart (since ConfigMap changes don't automatically trigger pod restarts). An alternative is patching the ConfigMap directly with `kubectl patch` — this works but doesn't use the repo as source of truth. After fixing the ConfigMap, the deployment **must** be restarted (or pods deleted) because existing pods have the old env values baked in. If the candidate only fixes the ConfigMap without restarting, the stuck pods will not recover.

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "The API is completely down — I'm getting a 502. Let me check pod state to see what's happening." |
| **After `get pods`** | "The pods are stuck at `Init:1/2`. That means the first init container completed but the second one is failing. Let me describe the pod to see what's going on with the init containers." |
| **After `describe pod`** | "The `wait-for-db` init container completed successfully, but `run-migrations` is failing. Let me check the logs for that container." |
| **After checking migration logs** | "The migration container is failing to connect to a host called `incident-database`. That doesn't look right — let me check what the actual database service is called and where this hostname is coming from." |
| **After checking ConfigMap and Services** | "The ConfigMap has `POSTGRES_HOST` set to `incident-database`, but the Postgres Service is named `incident-db-svc`. The ConfigMap has the wrong hostname. Interestingly, the first init container passed because it has the hostname hardcoded to `incident-db-svc` — it doesn't read from the ConfigMap. I'll fix the ConfigMap and restart the deployment." |
| **After fix** | "I've restored the correct hostname in the ConfigMap and restarted the deployment. Let me wait for the rollout and then verify end-to-end." |

---

## What to watch for as assessor

### Good signs

- Recognises `Init:1/2` means the second init container is failing and investigates that specifically
- Checks logs for the failing init container (`-c run-migrations`) rather than the main container
- Spots the bad hostname in the connection error
- Traces the hostname back to the ConfigMap
- Cross-references with the actual Postgres Service name to confirm the mismatch
- Notices and explains why `wait-for-db` passed (hardcoded hostname) while `run-migrations` failed (reads from ConfigMap)
- Fixes the ConfigMap AND restarts the deployment (understands both steps are needed)
- Uses the repo manifest as source of truth for the fix
- Verifies end-to-end with all endpoints after fix

### Amber flags

- Fixes with `kubectl edit` or `kubectl patch` instead of reapplying the manifest — works but doesn't use repo as source of truth
- Fixes the ConfigMap but forgets to restart the deployment (pods still have old env values)
- Doesn't notice or explain why `wait-for-db` passed — misses the hardcoded vs envFrom distinction
- Takes a long detour investigating the `wait-for-db` container even though it completed successfully
- Checks main container logs (there won't be any since the main container never started) before checking init container logs
- Takes more than ~15 commands to reach the fix

### Red flags

- Doesn't understand `Init:1/2` status — doesn't know how to investigate init containers
- Never checks init container logs (`-c` flag) — only checks main container logs and gets confused by empty output
- Sees connection error and investigates networking/NetworkPolicies instead of checking the hostname value
- Tries to create a Service named `incident-database` (fixing the wrong thing)
- Deletes and recreates pods hoping they self-heal without fixing the ConfigMap
- Doesn't verify end-to-end after fixing
- Can't explain what init containers do or why the pod is stuck

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to logs or config without checking pod status first | Starts with get pods, notices Init:1/2 | Reproduces symptom (curl), checks pods, immediately focuses on the Init:1/2 status |
| 2 | **Runtime flow** | Random commands, confused by init containers | Pods → describe → init container logs → finds bad hostname → fix | Curl → pods (Init:1/2) → describe (which init container?) → logs -c run-migrations → traces hostname to ConfigMap → compares with Service name → fix, tight path |
| 3 | **Signal reading** | Doesn't understand Init:1/2, checks wrong container | Spots migration failure, finds connection error | Reads Init:1/2 correctly, goes straight to second init container logs, identifies hostname mismatch, explains why first init container passed |
| 4 | **Hypothesis-driven** | Tries random restarts or investigates networking | "Migration is failing to connect, let me check the DB hostname" | "Init:1/2 means the second init container is failing. The migration container can't connect to 'incident-database' — that's not the DB service name. Let me check where that hostname is configured." |
| 5 | **Intentional commands** | 18+ commands, detours into networking/main container | ~12 commands, mostly on target | ~10 commands, no wasted steps — straight to init container logs, traces to ConfigMap, fixes |
| 6 | **Smallest fix** | Creates a new Service or changes the Postgres deployment | Patches ConfigMap but forgets restart | Fixes ConfigMap (via manifest apply) AND restarts deployment — understands both are needed |
| 7 | **End-to-end verification** | Declares fixed after pods show Running | Curls one endpoint | Curls /api/v1/status and /api/v1/incidents, confirms both return expected data |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings and fix steps | Narrates throughout: Init:1/2 meaning, which init container to check, hostname mismatch, hardcoded vs envFrom distinction, two-step fix rationale |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "Look at the pod status carefully. What stage are the pods stuck in?"

**Hint 2 (more specific):** "The pods have init containers. One of them is failing. Can you check its logs to see what's going wrong?"

**Hint 3 (pointed):** "The migration container is trying to connect to a database hostname. Where does it get that hostname from, and does it match the actual database service?"
