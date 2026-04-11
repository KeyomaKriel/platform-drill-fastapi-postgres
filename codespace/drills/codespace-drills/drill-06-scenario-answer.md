# Drill 06 — Debugging Answer Key (Assessor Copy)

**Failure domain:** Image pull / container creation failure (Tier 1)
**Injected fault:** The fleet-tracker deployment image was changed from `fleet-tracker:local` to `fleet-tracker:v2.1.0` — a tag that doesn't exist locally or in any registry.

---

## What will happen after injection

- The deployment triggers a rolling update with the new image tag
- New pods will fail with `ErrImagePull` → `ImagePullBackOff`
- Old pods remain Running (rolling update preserves them until new ones are ready)
- The app may still work partially via the old pods, or not at all depending on timing
- `imagePullPolicy: Never` means Kubernetes won't attempt to pull from a registry — it will fail immediately because the image isn't present locally

---

## Key signals the candidate should find

| Signal                                             | Where                                   | What it means                                |
| -------------------------------------------------- | --------------------------------------- | -------------------------------------------- |
| New pod(s) in `ErrImagePull` or `ImagePullBackOff` | `kubectl get pods`                      | Image can't be found                         |
| Old pods still `1/1 Running`                       | `kubectl get pods`                      | Rolling update hasn't torn them down         |
| `Failed to pull image "fleet-tracker:v2.1.0"`      | `kubectl describe pod <new-pod>`        | Wrong image tag                              |
| `Image: fleet-tracker:v2.1.0`                      | `kubectl describe pod <new-pod>`        | Confirms the incorrect tag                   |
| Manifest says `fleet-tracker:local`                | `cat manifests/tracker-deployment.yaml` | Source of truth shows correct tag            |
| `imagePullPolicy: Never`                           | `kubectl describe pod` or manifest      | Confirms this is a local image, not registry |

---

## Ideal diagnostic path (7-8 commands)

```bash
kubectl get pods                            # spot ErrImagePull / ImagePullBackOff on new pod(s)
kubectl describe pod <failing-pod>          # see "Failed to pull image fleet-tracker:v2.1.0"
cat manifests/tracker-deployment.yaml       # confirm intended image is fleet-tracker:local
kubectl apply -f manifests/tracker-deployment.yaml   # restore correct image
kubectl rollout status deployment/fleet-tracker -n fleet-ops  # wait for rollout
kubectl get pods                            # all Running/Ready
curl localhost:8080/api/v1/status           # 200 healthy
curl localhost:8080/api/v1/vehicles         # returns vehicle data
```

---

## What to watch for as assessor

### Good signs

- Recognises `ErrImagePull` / `ImagePullBackOff` immediately — this is a common pattern
- Goes to `describe pod` to read the full error message and see the image tag
- Checks the repo manifest to find what the image _should_ be
- Uses `kubectl apply -f manifests/` to fix (not a manual `kubectl set image` guess)
- Verifies end-to-end after fix
- Narrates: "The image tag has been changed to something that doesn't exist locally"

### Amber flags

- Fixes with `kubectl set image ... fleet-tracker:local` — correct result but didn't use the repo as source of truth
- Doesn't check the manifest to confirm what the correct image should be
- Checks configmaps, secrets, or services when the pod status already says `ImagePullBackOff`
- Takes more than ~10 commands to reach the fix

### Red flags

- Tries to pull or build the `v2.1.0` image instead of reverting to the correct tag
- Doesn't recognise `ErrImagePull` / `ImagePullBackOff` as an image problem
- Checks logs on a pod that hasn't started (there are no logs for a pod stuck on image pull)
- Deletes pods hoping they'll come back with the right image (they won't — the deployment spec is wrong)
- Can't explain what `imagePullPolicy: Never` means

---

## Evaluation criteria

| #   | Criteria                    | Needs Work                                         | Solid                                          | Strong                                                                                      |
| --- | --------------------------- | -------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------- |
| 1   | **Entry mode**              | Jumps to logs or config without reading pod status | Starts with get pods, spots the image issue    | Reads repo manifests first, then checks cluster                                             |
| 2   | **Runtime flow**            | Random commands, no logical progression            | Pods → describe → identify image → fix         | Pods → describe → compare with manifest → fix, tight path                                   |
| 3   | **Signal reading**          | Doesn't recognise ImagePullBackOff                 | Identifies wrong image from describe           | Spots the mismatch between live image and manifest immediately                              |
| 4   | **Hypothesis-driven**       | Tries things without stating why                   | "I think the image tag is wrong, let me check" | "The pod can't pull the image — let me check what tag is set and compare with the manifest" |
| 5   | **Intentional commands**    | 15+ commands, detours into config/services         | ~10 commands, mostly on-target                 | ~7 commands, no wasted steps                                                                |
| 6   | **Smallest fix**            | Tries to build/pull the wrong image                | kubectl set image to correct tag               | kubectl apply -f manifest (repo as source of truth)                                         |
| 7   | **End-to-end verification** | Declares fixed after pods are Running              | Curls one endpoint                             | Curls both /api/v1/status and /api/v1/vehicles                                              |
| 8   | **Communication**           | Silent or only speaks when stuck                   | Narrates key findings                          | Narrates throughout: what they see, what they think, what they'll do next                   |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "What do the pod statuses tell you?"

**Hint 2 (more specific):** "Look closely at the image on the failing pods — is it what you'd expect?"

**Hint 3 (pointed):** "Compare the image in the live deployment with what's in the manifest."
