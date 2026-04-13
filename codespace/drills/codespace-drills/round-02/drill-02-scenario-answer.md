# Drill 02 — Debugging Answer Key (Assessor Copy)

**App:** Django incident management API (`drill-app-django`)
**Namespace:** `incident-mgmt`
**Failure domain:** Service routing / port / endpoint failure (Tier 1)
**Injected fault:** The Service `incident-api-svc` selector label `component` was changed from `api` to `backend` — a value that matches no pods. The Service now has zero endpoints.

---

## What will happen after injection

- All pods remain Running and Ready (2/2 replicas) — the fault is at the Service layer, not pod level
- The Service `incident-api-svc` has zero endpoints because its selector `component: backend` matches no pods (pods have `component: api`)
- `curl localhost/api/v1/status` returns 502 or 503 from the nginx Ingress controller (upstream has no backends)
- `curl localhost/` also returns 502/503
- The Ingress resource itself is still correctly configured and pointing at `incident-api-svc`
- Direct pod access still works (e.g. `kubectl exec` or `kubectl port-forward` to a pod on port 8200)
- `kubectl get endpoints incident-api-svc -n incident-mgmt` shows an empty subset (no addresses)

This fault tests whether the candidate checks the full request path beyond just pod health. Pods are healthy, so the candidate must trace the gap between the Service and the pods.

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods `1/1 Running` and Ready | `kubectl get pods -n incident-mgmt` | Problem is not at pod level |
| `curl localhost/` returns 502/503 | Terminal | Ingress can't reach backend |
| Endpoints for `incident-api-svc` are empty | `kubectl get endpoints -n incident-mgmt` | Service has no matching pods |
| Service selector is `component: backend` | `kubectl describe svc incident-api-svc -n incident-mgmt` or `kubectl get svc -o yaml` | Selector doesn't match any pod labels |
| Pod labels include `component: api` | `kubectl get pods --show-labels -n incident-mgmt` | Pods use `api`, Service looks for `backend` |
| Manifest says selector `component: api` | `cat manifests/api-service.yaml` | Source of truth shows correct selector |

---

## Ideal diagnostic path (~8-10 commands)

```bash
# 1. Reproduce the symptom
curl localhost/api/v1/status                    # 502/503 — confirms the problem

# 2. Orient — check pod state
kubectl get pods -n incident-mgmt               # all Running/Ready — not a pod issue

# 3. Check endpoints — the critical signal
kubectl get endpoints -n incident-mgmt          # incident-api-svc has <none> — no backends!

# 4. Inspect the service selector
kubectl describe svc incident-api-svc -n incident-mgmt
# Look for: Selector: component=backend

# 5. Check pod labels
kubectl get pods -n incident-mgmt --show-labels  # labels show component=api

# 6. Compare with repo manifest (source of truth)
cat manifests/api-service.yaml                  # confirms selector should be component: api

# 7. Fix — reapply the correct manifest
kubectl apply -f manifests/ -n incident-mgmt

# 8. Verify endpoints are populated
kubectl get endpoints -n incident-mgmt          # incident-api-svc now has pod IPs

# 9. End-to-end verification
curl localhost/                                 # app info
curl localhost/api/v1/status                    # 200 healthy
curl localhost/api/v1/incidents                 # returns incident data
```

**Note on the fix:** `kubectl apply -f manifests/` is the preferred fix because it uses the repo manifests as source of truth. If the candidate applies just the service manifest (`kubectl apply -f manifests/api-service.yaml`), that's equally correct. An alternative fix is `kubectl patch` or `kubectl edit` to restore the selector — this works but doesn't use the repo as source of truth.

---

## Narration guide

| Stage | What the candidate should be saying |
|-------|-------------------------------------|
| **After curl** | "I'm getting a 502 from the Ingress. That usually means the Ingress can't reach its backend service. Let me check the pods and services." |
| **After `get pods`** | "All pods are Running and Ready. The problem isn't the pods themselves — something between the Ingress and the pods is broken." |
| **After `get endpoints`** | "The endpoints for `incident-api-svc` are empty — no pod IPs. The Service isn't selecting any pods. That explains the 502 — the Ingress has no upstream to forward to." |
| **After `describe svc`** | "The Service selector is `component: backend`. Let me check what labels the pods actually have." |
| **After checking pod labels** | "The pods have `component: api` but the Service is looking for `component: backend`. That's a selector mismatch — the Service can't find the pods." |
| **After checking manifest** | "The repo manifest has the correct selector `component: api`. The live Service has drifted. I'll reapply the manifest to restore the correct selector." |
| **After fix** | "Endpoints are now populated. Let me verify all three endpoints return expected responses." |

---

## What to watch for as assessor

### Good signs

- Reproduces the symptom with curl before diving into kubectl
- Checks endpoints early — this is the critical signal that immediately narrows the domain
- Recognises empty endpoints as a selector mismatch rather than a pod issue
- Compares Service selector with pod labels
- Cross-references with the repo manifest to find the correct selector value
- Uses `kubectl apply -f manifests/` to fix (repo as source of truth)
- Verifies end-to-end with all three endpoints after fix
- Narrates: "The Service selector doesn't match the pod labels — that's why there are no endpoints"

### Amber flags

- Fixes with `kubectl edit svc` or `kubectl patch` to correct the selector — works but doesn't use the repo as source of truth
- Checks pods and logs extensively before looking at endpoints or services
- Finds the empty endpoints but doesn't explain why (doesn't connect selector to labels)
- Doesn't check the manifest to confirm what the correct selector should be
- Takes more than ~12 commands to reach the fix

### Red flags

- Sees pods Running and declares "everything looks fine" — doesn't check services or endpoints
- Restarts pods or the deployment hoping it fixes the issue
- Focuses on Ingress config without checking whether the Service has backends
- Tries to relabel the pods to match the Service selector (fixing the wrong end)
- Doesn't verify end-to-end after fixing
- Can't explain the relationship between Service selectors, pod labels, and endpoints

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to pod logs without checking external access | Starts with curl and get pods, then checks services | Reproduces symptom (curl), confirms pods healthy, immediately checks endpoints |
| 2 | **Runtime flow** | Random commands, stuck at pod layer | Pods → services → identifies empty endpoints → fix | Curl → pods (healthy) → endpoints (empty) → describe svc (wrong selector) → pod labels → fix, clean progression |
| 3 | **Signal reading** | Doesn't check endpoints, or checks but misses they're empty | Spots empty endpoints and investigates Service selector | Immediately connects 502 + healthy pods to a Service/endpoint issue |
| 4 | **Hypothesis-driven** | Tries random restarts or config changes | "Endpoints are empty, must be a selector issue" | "502 with healthy pods means the Service can't find its backends. Let me check the selector and pod labels." |
| 5 | **Intentional commands** | 15+ commands, detours into logs/probes/networking | ~10 commands, mostly on target | ~8 commands, no wasted steps — straight to endpoints and selector |
| 6 | **Smallest fix** | Relabels pods or edits multiple resources | kubectl edit/patch svc to fix selector | kubectl apply -f manifests/ (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after seeing endpoints populate | Curls one endpoint | Curls /, /api/v1/status, and /api/v1/incidents |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings and decisions | Narrates throughout: symptom, ruling out pods, finding the selector mismatch, explaining root cause |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods look healthy. What else sits between a request and a pod?"

**Hint 2 (more specific):** "Check whether the Service actually has any backends to forward traffic to."

**Hint 3 (pointed):** "Compare the labels on the pods with the selector on the Service — do they match?"
