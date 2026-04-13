# Drill 10 — Debugging Answer Key (Assessor Copy)

**App:** Django incident API (`drill-app-django`)
**Failure domain:** Image Pull / Container Creation (Tier 1)
**Injected fault:** The Deployment image was changed from `incident-api:local` to `incident-api:v2.3.0` — a tag that doesn't exist locally or in any registry. `imagePullPolicy: Never` means Kubernetes won't attempt to pull from a registry and will fail immediately.

---

## What will happen after injection

- The Deployment triggers a rolling update with the new image tag
- New pods fail with `ErrImagePull` → `ErrImageNeverPull` → stuck
- Old pods remain Running (rolling update preserves them until new ones are Ready)
- The app may still partially work via the old pods
- `kubectl get pods` shows a mix: old pods Running, new pods in `ErrImagePull`/`ImagePullBackOff`
- The init containers on the new pods may also show image issues since the `run-migrations` init container uses the same image

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| New pods in `ErrImagePull` or `ImagePullBackOff` | `kubectl get pods` | Image can't be found |
| Old pods still `1/1 Running` | `kubectl get pods` | Rolling update preserving old replicas |
| `Failed to pull image "incident-api:v2.3.0"` | `kubectl describe pod <new-pod>` | Wrong image tag |
| `ErrImageNeverPull` | `kubectl describe pod <new-pod>` Events | `imagePullPolicy: Never` but image not on node |
| Image in manifest is `incident-api:local` | `cat Dockerfile` or `cat manifests/api-deployment.yaml` | Source of truth shows correct tag |
| `imagePullPolicy: Never` | `kubectl describe pod` or manifest | Confirms this is a local image, not from a registry |
| Deployment shows `READY 2/2 UP-TO-DATE 1` | `kubectl get deploy` | New RS created but its pods can't start |

---

## Ideal diagnostic path (~8-10 commands)

```bash
curl -i localhost/api/v1/status                                 # may still return 200 from old pods
kubectl get pods -n incident-mgmt                               # spot ErrImagePull on new pod(s)
kubectl get deploy -n incident-mgmt                             # UP-TO-DATE vs READY mismatch
kubectl describe pod <failing-pod> -n incident-mgmt             # see "Failed to pull image incident-api:v2.3.0"
cat manifests/api-deployment.yaml                               # confirm intended image is incident-api:local
kubectl apply -f manifests/api-deployment.yaml                  # restore correct image
kubectl rollout status deployment/incident-api -n incident-mgmt # wait for healthy rollout
kubectl get pods -n incident-mgmt                               # all Running/Ready
curl -i localhost/api/v1/status                                 # 200
curl -i localhost/api/v1/incidents                               # returns data
```

---

## Narration guide — what to say out loud at each stage

**After reproducing the symptom (curl may still work):**
> "The API is still responding — that means old pods are still serving. But I was told the rollout doesn't look right, so let me check deployment and pod state."

**After `kubectl get pods` (spot ErrImagePull):**
> "I can see new pods in ErrImagePull alongside the old Running pods. This is a failed rolling update — the new pods can't start because the image can't be pulled. Let me describe the failing pod to see the exact error."

**After `kubectl describe pod` (see image error):**
> "The Events show 'Failed to pull image incident-api:v2.3.0' with ErrImageNeverPull. The imagePullPolicy is Never, which means this is a local image that needs to be pre-loaded onto the node. The tag v2.3.0 doesn't exist locally. Let me check the manifest to see what the image should be."

**After `cat manifests/api-deployment.yaml` (see correct image):**
> "The manifest says `incident-api:local`. The live deployment was changed to `incident-api:v2.3.0` which doesn't exist. I'll re-apply the manifest to restore the correct image tag."

**After fix and verification:**
> "The rollout completed, all pods are Running and Ready with the correct image. Both `/api/v1/status` and `/api/v1/incidents` return 200. The image tag was changed to a version that doesn't exist locally — re-applying the manifest restored it."

---

## What to watch for as assessor

### Good signs

- Notices the deployment state (UP-TO-DATE vs READY mismatch) as well as pod state
- Recognises `ErrImagePull` / `ErrImageNeverPull` immediately as an image problem
- Goes to `describe pod` to read the full error and confirm the exact image tag
- Checks the manifest to find the correct image (not guessing)
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Explains what `imagePullPolicy: Never` means
- Verifies end-to-end after fix

### Amber flags

- Fixes with `kubectl set image ... incident-api:local` — correct but didn't use repo as source of truth
- Doesn't check the manifest, just guesses the correct tag from context
- Doesn't notice that old pods are still serving (doesn't understand rolling update behaviour)

### Red flags

- Tries to pull or build the `v2.3.0` image instead of reverting
- Doesn't recognise `ErrImagePull` as an image problem
- Tries `kubectl logs` on a pod that hasn't started (no logs for a pod stuck on image pull)
- Deletes pods expecting them to come back with the right image (the Deployment spec is still wrong)
- Can't explain what `imagePullPolicy: Never` means or why the image must be pre-loaded

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to logs or config | Checks pods, spots image error | Checks deployment state too — notices UP-TO-DATE mismatch |
| 2 | **Runtime flow** | Random commands, no progression | Pods → describe → identify image → fix | Curl → pods → deploy → describe → manifest → apply → verify |
| 3 | **Signal reading** | Doesn't recognise ErrImagePull | Identifies wrong image from describe | Spots the tag mismatch AND explains imagePullPolicy: Never |
| 4 | **Hypothesis-driven** | Tries things without reasoning | "The image tag is wrong, let me check the manifest" | "ErrImageNeverPull means the image needs to be local. The tag v2.3.0 doesn't exist — let me compare with the manifest." |
| 5 | **Intentional commands** | 15+ commands, detours | ~10 commands, mostly on target | ~8 commands, no wasted steps |
| 6 | **Smallest fix** | Tries to build the wrong image | kubectl set image to correct tag | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods Running | Curls one endpoint | Curls `/api/v1/status` and `/api/v1/incidents` |
| 8 | **Communication** | Silent | Narrates key findings | Narrates throughout, explains rolling update behaviour and why old pods still serve |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "What do the pod statuses tell you? Are all the pods the same?"

**Hint 2 (more specific):** "Look at the image on the failing pods — is it what you'd expect?"

**Hint 3 (pointed):** "Compare the image in the live deployment with what's in the manifest. What does imagePullPolicy: Never mean for how images are sourced?"
