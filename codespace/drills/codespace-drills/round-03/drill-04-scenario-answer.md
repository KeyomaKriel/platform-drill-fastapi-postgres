# Drill 04 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Image pull / container creation failure (Tier 1)
**Injected fault:** The image tag on the `incident-api` container in the `incident-api` Deployment was changed from `incident-api:local` to `incident-api:v1.5.0` — a tag that does not exist locally. With `imagePullPolicy: Never`, this causes an immediate `ErrImageNeverPull` error.

---

## What will happen after injection

- The deployment triggers a rolling update with the new image tag `incident-api:v1.5.0`
- New pods will fail with `ErrImageNeverPull` because the image does not exist locally and the pull policy forbids pulling from a registry
- Old pods remain Running because the rolling update strategy preserves them until new pods are Ready
- The app may still be reachable via old pods initially, but will degrade if old replicas are terminated or the rollout deadline is exceeded
- `kubectl get pods` will show new pods stuck in `ErrImageNeverPull` (or `ImagePullBackOff` in some display contexts, though with `Never` policy it is specifically `ErrImageNeverPull`)

---

## Key signals the candidate should find

| Signal | Where | What it means |
|---|---|---|
| New pods stuck in `ErrImageNeverPull` | `kubectl get pods -n incident-mgmt` | Container runtime can't pull the image and policy forbids pulling |
| Old pods still `1/1 Running` | `kubectl get pods -n incident-mgmt` | Rolling update can't proceed, old pods kept alive |
| `Container image "incident-api:v1.5.0" is not present on node ... and the image pull policy is set to Never` | `kubectl describe pod <new-pod> -n incident-mgmt` (Events) | Explicit: image tag doesn't exist locally, policy is Never |
| Image field shows `incident-api:v1.5.0` | `kubectl describe pod <new-pod> -n incident-mgmt` (Container spec) | Confirms the wrong tag was set |
| Manifest says `incident-api:local` | `cat manifests/api-deployment.yaml` | Source of truth shows the correct tag |
| `imagePullPolicy: Never` | Manifest or describe output | Explains why it doesn't try to pull from a registry |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Orient — check namespace and pod state
kubectl get pods -n incident-mgmt               # spot ErrImageNeverPull on new pods

# 2. Describe the failing pod to read events and spec
kubectl describe pod <failing-pod> -n incident-mgmt
# Look for: Events showing image not present and pull policy is Never
# Look for: Container image field showing incident-api:v1.5.0

# 3. Check what images are expected
cat manifests/api-deployment.yaml               # confirm image should be incident-api:local

# 4. Fix — reapply the correct manifest
kubectl apply -f manifests/api-deployment.yaml -n incident-mgmt

# 5. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 6. Verify pods
kubectl get pods -n incident-mgmt               # all Running/Ready

# 7. End-to-end verification
curl localhost/                                 # app info
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/api-deployment.yaml` is the preferred fix because it uses the repo manifest as source of truth. If `kubectl apply` does not fully resolve the issue (the annotation-based three-way merge may not detect the drift), the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

Alternative fix approach — directly set the image back:

```bash
kubectl set image deployment/incident-api incident-api=incident-api:local -n incident-mgmt
```

This works but doesn't use the repo manifest as source of truth.

---

## Narration guide

| Stage | What the candidate should be saying |
|---|---|
| **After `get pods`** | "I can see new pods stuck in `ErrImageNeverPull`. The old pods are still running — this looks like a rolling update that failed because the new pods can't start. The status suggests an image problem." |
| **After `describe pod`** | "The events confirm it — the container image `incident-api:v1.5.0` isn't present on the node, and the pull policy is set to `Never` so it won't try to fetch it from a registry. Someone changed the image tag to a version that doesn't exist locally." |
| **After checking manifest** | "The repo manifest specifies `incident-api:local` as the image tag. The live deployment has drifted — it's been set to `v1.5.0` which was never built or loaded. I'll reapply the manifest to restore the correct image." |
| **After fix** | "Let me verify the rollout completes and then check all three endpoints to confirm the app is fully operational." |

---

## What to watch for as assessor

### Good signs

- Recognises `ErrImageNeverPull` immediately as an image availability problem
- Goes to `describe pod` and reads the Events section to get the full error message
- Understands the interaction between the missing image tag and `imagePullPolicy: Never`
- Checks the repo manifest to find the correct image tag
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with all three endpoints after fix
- Narrates clearly: "The image tag was changed to one that doesn't exist locally, and the pull policy prevents pulling from a registry"

### Amber flags

- Fixes with `kubectl set image` to correct the tag — works but doesn't use the repo as source of truth
- Fixes with `kubectl edit` — works but same concern about not using manifests
- Tries to pull or build the `v1.5.0` image instead of restoring the correct tag — solving the wrong problem
- Doesn't explain why `imagePullPolicy: Never` matters in this context
- Takes more than ~12 commands to reach the fix

### Red flags

- Doesn't recognise `ErrImageNeverPull` — goes chasing networking, probes, or config issues
- Tries to change `imagePullPolicy` to `Always` or `IfNotPresent` — the image `v1.5.0` doesn't exist anywhere, and changing the policy is the wrong fix
- Tries to restart or delete pods hoping they'll self-heal (they won't — the deployment spec still references the wrong image)
- Doesn't verify end-to-end after fixing
- Can't articulate why the pods failed — just "fixed it" without explaining the root cause

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|---|---|---|---|
| 1 | **Entry mode** | Jumps to logs or networking without checking pod status | Starts with get pods, spots the image error | Checks repo structure first, then cluster state — systematic |
| 2 | **Runtime flow** | Random commands, no logical progression | Pods → describe → identify wrong image → fix | Pods → describe → check manifest for correct tag → apply manifest → verify, tight path |
| 3 | **Signal reading** | Doesn't recognise ErrImageNeverPull | Reads describe output and identifies the wrong image tag | Immediately connects the error to a tag mismatch and explains the role of imagePullPolicy: Never |
| 4 | **Hypothesis-driven** | Tries things without stating why | "I think the image tag is wrong, let me check the manifest" | "The pod can't start because the image isn't available locally and the pull policy is Never. Let me check what the correct tag should be." |
| 5 | **Intentional commands** | 15+ commands, detours into config/networking | ~10 commands, mostly on-target | ~7-8 commands, no wasted steps |
| 6 | **Smallest fix** | Changes imagePullPolicy or tries to build v1.5.0 | kubectl set image to restore the correct tag | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods are Running | Curls one endpoint | Curls /, /api/v1/status, and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates throughout: what they see, what they think, what they'll do next |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "What state are the new pods in? What does that status usually tell you about the container lifecycle?"

**Hint 2 (more specific):** "The error is about the container image. What image is the pod trying to use, and does it match what's in the manifest?"

**Hint 3 (pointed):** "Compare the image tag in the live deployment spec with the tag in the repo manifest. Also check what the `imagePullPolicy` is set to."
