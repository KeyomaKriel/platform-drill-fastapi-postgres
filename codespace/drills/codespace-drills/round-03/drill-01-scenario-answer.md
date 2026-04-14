# Drill 01 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Service routing / endpoint failure (Tier 1)
**Injected fault:** The Service `incident-api-svc` selector was changed from `component: api` to `component: web`. Since no pods carry the label `component: web`, the Service has zero endpoints. Ingress routes to the Service, so all external traffic returns 502/503.

---

## What will happen after injection

- The Service `incident-api-svc` selector no longer matches the Deployment's pod labels (`component: api`)
- The Endpoints object for `incident-api-svc` becomes empty — zero backend pods
- All pods remain `Running` and `Ready` — nothing visibly wrong at the pod level
- `curl localhost/api/v1/status` and `curl localhost/api/v1/incidents` return 502 Bad Gateway from the nginx Ingress controller
- The Ingress itself looks fine — it still references the Service
- This is a deceptive fault: pods healthy, Deployment healthy, Service exists, Ingress exists — but the routing chain is broken at the Service-to-Pod selector level

---

## Key signals the candidate should find

| Signal | Where | What it means |
|---|---|---|
| Pods are `1/1 Running` and `Ready` | `kubectl get pods -n incident-mgmt` | Problem is NOT at the pod level — eliminates crash, image, probe, config faults |
| 502 Bad Gateway from curl | `curl localhost/api/v1/status` | Ingress can reach the controller but the backend is unavailable |
| Endpoints for `incident-api-svc` shows `<none>` | `kubectl get endpoints -n incident-mgmt` | Service has no backing pods — selector doesn't match any pods |
| Service selector is `component: web` | `kubectl describe svc incident-api-svc -n incident-mgmt` or `kubectl get svc -o yaml` | Selector doesn't match the pod labels |
| Pod labels show `component: api` | `kubectl get pods --show-labels -n incident-mgmt` | Confirms the mismatch |
| Manifest shows `selector: component: api` | `cat manifests/api-service.yaml` | Source of truth confirms the Service selector should be `component: api` |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Orient — check namespace and pod state
kubectl get pods -n incident-mgmt               # all Running/Ready — pods look fine

# 2. Check endpoints (critical step for this fault)
kubectl get endpoints -n incident-mgmt           # incident-api-svc has <none> — no backends

# 3. Describe the Service to see the selector
kubectl describe svc incident-api-svc -n incident-mgmt
# Or: kubectl get svc incident-api-svc -n incident-mgmt -o yaml
# Look for: Selector: component=web

# 4. Check pod labels to confirm the mismatch
kubectl get pods -n incident-mgmt --show-labels  # pods have component=api, not component=web

# 5. Compare with repo manifest (source of truth)
cat manifests/api-service.yaml                   # confirm selector should be component: api

# 6. Fix — reapply the correct manifest
kubectl apply -f manifests/api-service.yaml -n incident-mgmt

# 7. Verify endpoints are now populated
kubectl get endpoints -n incident-mgmt           # incident-api-svc now shows pod IPs

# 8. End-to-end verification
curl localhost/api/v1/status                     # 200 healthy
curl localhost/api/v1/incidents                  # returns incident data
```

---

## Narration guide

| Stage | What the candidate should be saying |
|---|---|
| **After `get pods`** | "All pods are Running and Ready. The problem isn't at the pod level — the containers are healthy. I need to look further up the routing chain." |
| **After checking endpoints** | "The Service `incident-api-svc` has no endpoints. That means the Service selector doesn't match any running pods. That would explain the 502 — the Ingress is routing to a Service with no backends." |
| **After describing the Service** | "The Service selector is `component: web`, but the pods are labelled `component: api`. That's the mismatch. The Service is looking for pods that don't exist." |
| **After checking manifest** | "The repo manifest shows the selector should be `component: api`. The live Service has drifted — someone changed the selector to `component: web`. I'll reapply the manifest." |
| **After fix** | "Let me verify the endpoints are populated now and then test the full routing chain end-to-end." |

---

## What to watch for as assessor

### Good signs

- Recognises that healthy pods plus 502 means the problem is in the Service or Ingress layer, not at the pod level
- Checks endpoints early — this is the key signal for selector mismatch
- Connects empty endpoints to a selector mismatch (not to pod crashes or scaling issues)
- Cross-references pod labels with Service selector
- Checks the repo manifest to confirm what the correct selector should be
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies endpoints are populated after fixing, then curls both endpoints
- Narrates the routing chain: Ingress -> Service -> Endpoints -> Pods

### Amber flags

- Fixes with `kubectl edit` or `kubectl patch` to correct the selector — works but doesn't use the repo as source of truth
- Takes a long time to check endpoints — spends time in logs, describe pod, or probe investigation first
- Doesn't clearly articulate why the selector mismatch causes 502s
- Checks the Ingress extensively before checking the Service/endpoints
- Takes more than ~12 commands to reach the fix

### Red flags

- Sees all pods healthy and declares "everything looks fine" without checking connectivity
- Focuses on pod logs or container configuration when pods are clearly Running/Ready
- Tries to fix by restarting pods, scaling the deployment, or deleting pods
- Changes pod labels to `component: web` to match the bad selector (fixing the wrong side)
- Doesn't check endpoints at all — cannot explain the 502
- Doesn't verify end-to-end after fixing
- Can't articulate the Service selector -> Endpoints -> routing chain

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|---|---|---|---|
| 1 | **Entry mode** | Jumps to logs or describe pod, confused by healthy pods | Starts with get pods, recognises pods are fine, shifts to Service layer | Checks pods, quickly pivots to endpoints when pods are healthy — systematic |
| 2 | **Runtime flow** | Stuck on pod-level diagnostics for a long time | Pods -> endpoints -> service selector -> fix | Pods -> curl -> endpoints -> service describe -> pod labels -> manifest -> fix, tight chain |
| 3 | **Signal reading** | Doesn't check endpoints, can't explain why 502 occurs | Finds empty endpoints and connects to selector issue | Immediately connects healthy pods + 502 to a Service/routing problem and checks endpoints first |
| 4 | **Hypothesis-driven** | "Let me try restarting pods" without a theory | "Endpoints are empty, I think the selector is wrong" | "Pods are healthy but the Service has no endpoints — this means the selector doesn't match the pod labels. Let me compare them." |
| 5 | **Intentional commands** | 15+ commands, detours into logs/probes/config | ~10 commands, mostly on-target | ~7-8 commands, no wasted steps, each command has a clear purpose |
| 6 | **Smallest fix** | Changes pod labels to match bad selector, or edits inline | kubectl edit to fix the selector | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after reapplying | Curls one endpoint | Checks endpoints are populated, then curls /api/v1/status and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings | Narrates the routing chain throughout: "Ingress -> Service -> Endpoints -> Pods, the break is at Service -> Endpoints" |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods look healthy. What else in the routing chain could explain why traffic isn't reaching them?"

**Hint 2 (more specific):** "When a Service exists but traffic doesn't reach the pods, what object sits between the Service and the pods that you could check?"

**Hint 3 (pointed):** "Check the endpoints for the Service. If they're empty, compare the Service selector with the actual pod labels."
