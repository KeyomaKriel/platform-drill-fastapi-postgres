# Drill 08 — Debugging Answer Key (Assessor Copy)

**App:** Go inventory API (`drill-app-go`)
**Failure domain:** Startup / crash failure (Tier 2)
**Injected fault:** A `command` override was added to the container spec: `["./inventory-service"]`. The actual binary in the image is `./inventory-api`. The container starts, immediately fails with "exec: ./inventory-service: no such file or directory", and enters CrashLoopBackOff.

---

## What will happen after injection

- The deployment triggers a rolling update with the new pod spec
- New pods complete the init container (wait-for-db) successfully
- The main container starts and immediately crashes — the binary `./inventory-service` doesn't exist
- Pods cycle through `Error` → `CrashLoopBackOff` with increasing restart backoff
- Old pods may remain Running briefly (rolling update preserves them until new ones are ready)
- `kubectl logs` on the crashing pod shows the exec error (or may be empty if the shell can't even find the binary)
- `kubectl describe pod` shows `State: Waiting / CrashLoopBackOff` and restart count climbing
- The Dockerfile's `CMD ["./inventory-api"]` is overridden by the deployment's `command` field — Kubernetes `command` maps to Docker `ENTRYPOINT`, taking precedence over `CMD`

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| New pods in `CrashLoopBackOff` or `Error` | `kubectl get pods` | Container is crashing on startup |
| High restart count | `kubectl get pods` | Container keeps crashing and restarting |
| `exec ./inventory-service: no such file or directory` | `kubectl logs <pod>` | Wrong binary name |
| `Command: ./inventory-service` | `kubectl describe pod` | Shows the overridden command |
| Init container completed OK | `kubectl describe pod` | Init container is not the problem |
| Dockerfile CMD is `./inventory-api` | `cat Dockerfile` | The correct binary name |
| No `command` in manifest | `cat manifests/api-deployment.yaml` | Manifest doesn't specify command — something changed at runtime |
| Old pods still Running | `kubectl get pods` | Rolling update strategy preserving old pods |

---

## Ideal diagnostic path (~8-10 commands)

```bash
kubectl get pods -n warehouse-sys              # spot CrashLoopBackOff / Error on new pods
kubectl describe pod <crashing-pod> -n warehouse-sys  # see Command: ./inventory-service, restart count, State: CrashLoopBackOff
kubectl logs <crashing-pod> -n warehouse-sys   # see "exec ./inventory-service: no such file or directory"
cat Dockerfile                                 # confirm binary is ./inventory-api, CMD ["./inventory-api"]
cat manifests/api-deployment.yaml              # no command override in manifest — live spec diverged
kubectl apply -f manifests/api-deployment.yaml # restore deployment (removes the command override)
kubectl rollout status deployment/inventory-api -n warehouse-sys  # wait for healthy rollout
kubectl get pods -n warehouse-sys              # all Running/Ready
curl localhost/readyz                          # 200
curl localhost/api/v1/products                 # returns product data
```

---

## Narration guide — what to say out loud at each stage

**After `kubectl get pods` (spot CrashLoopBackOff):**
> "I can see new pods in CrashLoopBackOff with a high restart count. The old pods are still running — this looks like a rolling update that's failing. Let me describe one of the crashing pods to see why."

**After `kubectl describe pod` (see command override and crash state):**
> "The container state shows CrashLoopBackOff. I can see the command is set to `./inventory-service`. Let me check the logs to see what error it's producing."

**After `kubectl logs` (see exec error):**
> "The error is 'exec ./inventory-service: no such file or directory'. The binary doesn't exist in the container. Let me check the Dockerfile to see what the binary is actually called."

**After `cat Dockerfile` (see correct binary name):**
> "The Dockerfile builds the binary as `./inventory-api` and the CMD is `./inventory-api`. But the deployment is trying to run `./inventory-service` — a different name. Let me check the manifest to see if this command override is supposed to be there."

**After `cat manifests/api-deployment.yaml` (no command in manifest):**
> "The manifest doesn't have a `command` field at all — it relies on the Dockerfile CMD. Something changed the live deployment to add a command override with the wrong binary name. I'll re-apply the manifest to restore it."

**After `kubectl apply` and rollout:**
> "The deployment is rolling out with the corrected spec. Let me wait for it to finish and then verify end-to-end."

**After verification curls:**
> "Both `/readyz` and `/api/v1/products` return 200. The fix is confirmed — the container command was overridden with a wrong binary name, and re-applying the manifest removed that override."

---

## What to watch for as assessor

### Good signs

- Recognises CrashLoopBackOff immediately as a startup failure
- Goes to `describe pod` and `logs` to read the actual error
- Connects the wrong binary name to the Dockerfile or manifest
- Understands the relationship between Kubernetes `command` and Docker `CMD`/`ENTRYPOINT`
- Checks the manifest to see that it doesn't include the command override (recognises live drift)
- Uses `kubectl apply -f manifests/` to fix
- Verifies end-to-end after fix

### Amber flags

- Fixes by manually patching the command to `./inventory-api` — correct result but didn't use the manifest
- Doesn't check the Dockerfile to confirm the correct binary name
- Doesn't notice that the manifest has no `command` field (misses the live-vs-repo drift)
- Checks configmaps or secrets when the error clearly says "no such file or directory"

### Red flags

- Tries to rebuild the image with a different binary name
- Doesn't read the logs — guesses at the problem from pod status alone
- Can't explain the relationship between Kubernetes `command`/`args` and Docker `ENTRYPOINT`/`CMD`
- Deletes pods expecting them to recover (the deployment spec is still wrong)
- Spends time debugging the init container when it completed successfully

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Skips pod status or goes straight to config | Starts with get pods, spots CrashLoopBackOff | Reproduces symptom first (curl fails), then checks pods |
| 2 | **Runtime flow** | Random commands, no progression from symptom to cause | Pods → describe → logs → identify wrong binary → fix | Curl → pods → describe → logs → Dockerfile → manifest → apply → verify, clean path |
| 3 | **Signal reading** | Doesn't read the exec error in logs | Reads the error and identifies wrong binary name | Connects binary name to Dockerfile CMD and notices manifest has no command override (live drift) |
| 4 | **Hypothesis-driven** | Tries random fixes without reading the error | "The binary name is wrong, let me check what it should be" | "The command was overridden at runtime — the manifest doesn't have this, so re-applying should fix it" |
| 5 | **Intentional commands** | 15+ commands, detours into networking or ingress | ~10 commands, mostly on target | ~8 commands, every step has a reason |
| 6 | **Smallest fix** | Tries to rebuild the image or edit the Dockerfile | kubectl patch to correct the command | kubectl apply -f manifest (removes the override entirely, repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after pods are Running | Curls one endpoint | Curls `/readyz` and `/api/v1/products` through Ingress |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates throughout — what they see, what they think, what they'll do next (see narration guide above) |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "What do the pod statuses and restart counts tell you?"

**Hint 2 (more specific):** "Check the logs on one of the crashing pods — what's the actual error?"

**Hint 3 (pointed):** "Compare the command the container is trying to run with what the Dockerfile says the binary is called."
