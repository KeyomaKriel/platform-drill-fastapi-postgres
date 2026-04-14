# Drill 04 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Image pull / container creation failure (Tier 1)
**Injected fault:** The container image tag on the `incident-api` Deployment was changed from `incident-api:local` to `incident-api:v2.1.0` — a tag that does not exist locally or in any registry. Because `imagePullPolicy: Never` is set, the kubelet will not attempt a pull and immediately fails with `ErrImageNeverPull`.

---

## What will happen after injection

- The `kubectl set image` triggers a rolling update with the new pod template referencing `incident-api:v2.1.0`
- New pods are created but the container cannot start — the kubelet reports `ErrImageNeverPull` because the image tag doesn't exist locally and the pull policy is `Never`
- Pod status shows `ErrImageNeverPull` (or `ImagePullBackOff` if the pull policy were different, but here it is specifically `ErrImageNeverPull`)
- The rolling update stalls — new pods never become Ready, so old pods are preserved by the rollout strategy
- Depending on timing and `maxUnavailable` settings, the user may see a mix of old pods (1/1 Ready) and new pods stuck in `ErrImageNeverPull`
- The app may still be partially reachable via old pods, or may return 502/503 if old pods have been scaled down
- `kubectl describe pod` on a new pod will show: `Warning  ErrImageNeverPull  ...  Container image "incident-api:v2.1.0" is not present on node ... and the image pull policy is Never`
- `kubectl get events -n incident-mgmt` will show the image-related failure events

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| New pods stuck in `ErrImageNeverPull` | `kubectl get pods -n incident-mgmt` | Container image not found locally, pull policy prevents remote pull |
| Old pods still `1/1 Running` | `kubectl get pods -n incident-mgmt` | Rolling update preserves old pods because new ones can't start |
| `Container image "incident-api:v2.1.0" is not present on node` | `kubectl describe pod <new-pod> -n incident-mgmt` (Events) | The image tag doesn't exist on the node |
| Image is `incident-api:v2.1.0` | `kubectl describe pod <new-pod> -n incident-mgmt` (Container spec) | Wrong tag — should be `incident-api:local` |
| `imagePullPolicy: Never` | `kubectl describe pod <new-pod> -n incident-mgmt` (Container spec) | Explains why it's `ErrImageNeverPull` not `ImagePullBackOff` |
| Manifest says `image: incident-api:local` | `cat manifests/api-deployment.yaml` | Source of truth shows the correct image tag |
| Rollout is stalled | `kubectl rollout status deployment/incident-api -n incident-mgmt` | Waiting for new pods that will never start |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # may work (old pods) or 502

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # spot new pods in ErrImageNeverPull, old pods 1/1

# 3. Describe the failing pod to read events and spec
kubectl describe pod <new-pod> -n incident-mgmt
# Look for: Events showing 'ErrImageNeverPull' and 'image not present on node'
# Look for: Image is incident-api:v2.1.0 (wrong tag)
# Notice:  imagePullPolicy: Never

# 4. Compare with repo manifest (source of truth)
cat manifests/api-deployment.yaml               # image should be incident-api:local

# 5. Fix — reapply the correct manifest
kubectl apply -f manifests/ -n incident-mgmt

# 6. Wait for rollout
kubectl rollout status deployment/incident-api -n incident-mgmt --timeout=90s

# 7. Verify pods
kubectl get pods -n incident-mgmt               # all pods 1/1 Running/Ready

# 8. End-to-end verification
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth. `kubectl apply -f manifests/api-deployment.yaml` is equally correct. An alternative fix using `kubectl set image deployment/incident-api -n incident-mgmt incident-api=incident-api:local` works and is acceptable — it directly restores the correct image tag. Using `kubectl edit` or `kubectl rollout undo` also works but doesn't use the repo as source of truth. If `kubectl apply` doesn't resolve the drift (annotation-based three-way merge edge case), the fallback is:

```bash
kubectl replace -f manifests/api-deployment.yaml -n incident-mgmt
```

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "The API is either down or intermittent. Let me check what's happening with the pods." |
| **After `get pods`** | "I can see new pods stuck in `ErrImageNeverPull`. The old pods are still running. This looks like a rolling update that's stalled because the new pods can't pull their image." |
| **After `describe pod`** | "The events confirm it — the image `incident-api:v2.1.0` isn't present on the node, and the pull policy is set to `Never` so it won't try to pull from a registry. The image tag was changed to something that doesn't exist locally." |
| **After checking manifest** | "The repo manifest specifies `incident-api:local` as the image tag. The live deployment has been changed to `v2.1.0` — that's the drift. I'll reapply the manifests to restore the correct image." |
| **After fix** | "The rollout is progressing with the correct image. Let me wait for it to complete and verify all endpoints." |

---

## What to watch for as assessor

### Good signs

- Immediately recognises `ErrImageNeverPull` as an image issue — doesn't confuse it with a crash or readiness failure
- Goes to `describe pod` and reads both the container spec (image tag) and events
- Connects `ErrImageNeverPull` to the `imagePullPolicy: Never` setting — understands why it's not `ImagePullBackOff`
- Cross-references with the repo manifest to identify the correct image tag
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth), or `kubectl set image` with the correct tag
- Verifies end-to-end with all endpoints after fix
- Narrates clearly: "The image tag was changed to a version that doesn't exist locally, and the pull policy prevents pulling from a registry"

### Amber flags

- Fixes with `kubectl rollout undo` — works but doesn't demonstrate understanding of what changed
- Spends time investigating whether `v2.1.0` might exist in a registry or needs to be built
- Tries to change the `imagePullPolicy` to `Always` or `IfNotPresent` instead of fixing the tag
- Recognises the image issue but takes a long path to the fix (checking networking, services, etc.)
- Doesn't explain the relationship between the image tag and the pull policy
- Takes more than ~10 commands to reach the fix

### Red flags

- Sees `ErrImageNeverPull` but doesn't understand what it means — investigates networking or DNS
- Tries to `docker pull` the image or build a `v2.1.0` tag (fixing the wrong side)
- Deletes pods hoping they'll self-heal (new pods from the same ReplicaSet will have the same broken image)
- Focuses on services, ingress, or probes when the pod can't even start its container
- Doesn't read `describe pod` — the most direct source of image failure information
- Doesn't verify end-to-end after fixing
- Cannot explain what `imagePullPolicy: Never` means in context

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to logs or networking without checking pod status | Starts with get pods, notices ErrImageNeverPull | Reproduces symptom (curl), checks pods, immediately identifies the image pull error state |
| 2 | **Runtime flow** | Random commands, stuck investigating services or networking | Pods → describe → identifies image issue → fix | Curl → pods (ErrImageNeverPull) → describe (wrong tag + Never policy) → check manifest → fix, tight path |
| 3 | **Signal reading** | Doesn't recognise ErrImageNeverPull, or treats it as a generic crash | Spots the image error and identifies the wrong tag | Immediately connects ErrImageNeverPull to the image tag + pull policy, explains the mechanism |
| 4 | **Hypothesis-driven** | Tries random restarts or investigates networking | "Image can't be pulled, let me check what tag it's using" | "ErrImageNeverPull means the image isn't on the node and the policy prevents pulling. The tag was changed to v2.1.0 which doesn't exist locally. The manifest says it should be incident-api:local." |
| 5 | **Intentional commands** | 12+ commands, detours into logs/networking/Ingress | ~8 commands, mostly on target | ~6 commands, no wasted steps — straight to describe, spots image tag, checks manifest, fixes |
| 6 | **Smallest fix** | Changes imagePullPolicy or tries to build the v2.1.0 image | kubectl set image with the correct tag | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods show Running | Curls one endpoint | Curls /api/v1/status and /api/v1/incidents, checks all pods are 1/1 Ready |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings and the fix | Narrates throughout: symptom, ErrImageNeverPull meaning, pull policy explanation, tag drift from manifest, fix rationale |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "Look at the pod status carefully — are all the pods in the same state, or are some different from others?"

**Hint 2 (more specific):** "Some pods can't even start their containers. What could prevent a container from starting before it even runs your application code?"

**Hint 3 (pointed):** "Check the image specification on one of the failing pods. Does that image actually exist where Kubernetes is looking for it?"
