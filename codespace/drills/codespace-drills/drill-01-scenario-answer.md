# Drill 01 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Config / Secret / env failure (Tier 1)
**Injected fault:** The Secret reference in the `incident-api` Deployment was changed from `incident-api-credentials` to `incident-api-secrets` — a Secret name that does not exist. Both the main container and the `run-migrations` init container were patched with the bad reference.

---

## What will happen after injection

- The deployment triggers a rolling update with the modified pod template
- New pods will fail with `CreateContainerConfigError` because the referenced Secret `incident-api-secrets` does not exist
- The init container `run-migrations` (index 1) also references the same bad Secret via `envFrom`, so init containers will fail before the main container even starts
- Old pods remain Running because the rolling update strategy preserves them until new pods are Ready
- The app may still be reachable via old pods, or become unreachable if the old replicas are eventually terminated or if the rollout deadline is exceeded
- `kubectl get pods` will show new pods stuck in `Init:CreateContainerConfigError` (since the init container fails first)

---

## Key signals the candidate should find

| Signal | Where | What it means |
|---|---|---|
| New pods stuck in `Init:CreateContainerConfigError` | `kubectl get pods -n incident-mgmt` | Init container can't start due to missing config |
| Old pods still `1/1 Running` | `kubectl get pods -n incident-mgmt` | Rolling update hasn't torn them down yet |
| `Error: secret "incident-api-secrets" not found` | `kubectl describe pod <new-pod> -n incident-mgmt` (Events) | The referenced Secret doesn't exist |
| `envFrom` references `incident-api-secrets` | `kubectl describe pod <new-pod> -n incident-mgmt` (Init Container / Container spec) | Confirms the wrong Secret name |
| Secret in namespace is `incident-api-credentials` | `kubectl get secrets -n incident-mgmt` | The real Secret has a different name |
| Manifest says `incident-api-credentials` | `cat manifests/api-deployment.yaml` | Source of truth shows correct name |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Orient — check namespace and pod state
kubectl get pods -n incident-mgmt               # spot Init:CreateContainerConfigError on new pods

# 2. Describe the failing pod to read events and spec
kubectl describe pod <failing-pod> -n incident-mgmt
# Look for: Events showing 'secret "incident-api-secrets" not found'
# Look for: envFrom entries referencing the wrong Secret name

# 3. Check what Secrets actually exist
kubectl get secrets -n incident-mgmt            # see incident-api-credentials exists, not incident-api-secrets

# 4. Compare with repo manifest (source of truth)
cat manifests/api-deployment.yaml               # confirm envFrom should reference incident-api-credentials

# 5. Fix — reapply the correct manifest
kubectl apply -f manifests/api-deployment.yaml -n incident-mgmt

# 6. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 7. Verify pods
kubectl get pods -n incident-mgmt               # all Running/Ready

# 8. End-to-end verification
curl localhost/                                 # app info
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/api-deployment.yaml` is the preferred fix because it uses the repo manifest as source of truth. However, if `kubectl apply` does not fully resolve the issue (the annotation-based three-way merge may not detect the drift if the last-applied annotation was also modified by the patch), the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

This does a full replacement of the resource spec, bypassing the diff-based merge.

---

## Narration guide

| Stage | What the candidate should be saying |
|---|---|
| **After `get pods`** | "I can see new pods stuck in `Init:CreateContainerConfigError`. The old pods are still running — this looks like a rolling update that can't proceed because the new pods fail during init." |
| **After `describe pod`** | "The events say the Secret `incident-api-secrets` wasn't found. The init container `run-migrations` uses `envFrom` to load a Secret, and the name referenced doesn't match anything in the namespace." |
| **After `get secrets`** | "There's `incident-api-credentials` but no `incident-api-secrets`. Someone changed the Secret reference name — it's a typo or misconfiguration." |
| **After checking manifest** | "The repo manifest has the correct name `incident-api-credentials`. The live deployment has drifted from the source of truth. I'll reapply the manifest to fix this." |
| **After fix** | "Let me verify the rollout completes and then check all three endpoints to confirm the app is fully operational." |

---

## What to watch for as assessor

### Good signs

- Recognises `CreateContainerConfigError` as a config reference problem — not a crash or image issue
- Goes to `describe pod` and reads the Events section carefully
- Notices the error message names the specific Secret that's missing
- Cross-references with `kubectl get secrets` to confirm what actually exists
- Checks the repo manifest to find the correct Secret name
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with all three endpoints after fix
- Narrates clearly: "The Secret reference is wrong — the deployment is looking for a Secret that doesn't exist"

### Amber flags

- Fixes with `kubectl edit` or `kubectl patch` to correct the Secret name — works but doesn't use the repo as source of truth
- Creates a new Secret called `incident-api-secrets` instead of fixing the reference — technically works but wrong approach (creating resources to match bad config)
- Doesn't check the manifest to confirm what the correct Secret name should be
- Checks logs when pods haven't started (there are no logs for a pod stuck on init container config error)
- Takes more than ~12 commands to reach the fix

### Red flags

- Doesn't recognise `CreateContainerConfigError` — goes chasing image pull, networking, or probe issues
- Tries to restart or delete pods hoping they'll self-heal (they won't — the deployment spec is wrong)
- Creates the missing Secret `incident-api-secrets` with guessed values
- Doesn't verify end-to-end after fixing
- Can't articulate why the pods failed — just "fixed it" without explaining the root cause

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|---|---|---|---|
| 1 | **Entry mode** | Jumps to logs or config without checking pod status | Starts with get pods, spots the init error | Checks repo structure first, then cluster state — systematic |
| 2 | **Runtime flow** | Random commands, no logical progression | Pods → describe → identify missing Secret → fix | Pods → describe → list secrets → compare with manifest → fix, tight path |
| 3 | **Signal reading** | Doesn't recognise CreateContainerConfigError | Reads describe output and finds the missing Secret | Immediately connects the error to a Secret reference mismatch and checks what exists |
| 4 | **Hypothesis-driven** | Tries things without stating why | "I think a Secret reference is wrong, let me check" | "The pod can't configure its containers — the init container references a Secret that doesn't exist. Let me check what the correct name should be." |
| 5 | **Intentional commands** | 15+ commands, detours into networking/probes | ~10 commands, mostly on-target | ~7-8 commands, no wasted steps |
| 6 | **Smallest fix** | Creates a new Secret to match the bad reference | kubectl edit to fix the name | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods are Running | Curls one endpoint | Curls /, /api/v1/status, and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates throughout: what they see, what they think, what they'll do next |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "What state are the new pods in? What does that status usually mean?"

**Hint 2 (more specific):** "The error mentions something the pod needs but can't find. What resources does this pod depend on for its environment?"

**Hint 3 (pointed):** "Compare the Secret names referenced in the live deployment spec with the Secrets that actually exist in the namespace."
