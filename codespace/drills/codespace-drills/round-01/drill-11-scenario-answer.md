# Drill 11 — Debugging Answer Key (Assessor Copy)

**App:** Django incident API (`drill-app-django`)
**Failure domain:** Service Routing / Port / Endpoint Failure (Tier 1)
**Injected fault:** The Service `incident-api-svc` selector was patched from `component: api` to `component: backend`. Since no pods carry the label `component: backend`, the Service has zero endpoints. All traffic through the Service (and therefore through Ingress) returns 502 because nginx has no upstream to forward to.

---

## What will happen after injection

- The Service selector changes immediately — no rolling update, no pod restart
- Pods remain `1/1 Running` and fully healthy (this is a Service-layer fault, not a pod fault)
- `kubectl get endpoints incident-api-svc -n incident-mgmt` shows an empty subset (no addresses)
- Ingress sends traffic to the Service, but nginx gets no healthy upstream — returns 502
- `curl localhost/api/v1/status` returns 502 Bad Gateway
- `curl localhost/api/v1/incidents` also returns 502
- Port-forwarding directly to the pod still works (the app is fine)
- Health and liveness probes continue to pass (kubelet probes pods directly, not via the Service)

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods `1/1 Running`, no restarts | `kubectl get pods` | Pods are healthy — problem is not at the pod layer |
| 502 Bad Gateway | `curl localhost/api/v1/status` | Ingress has no upstream to forward to |
| Endpoints empty (no addresses) | `kubectl get endpoints incident-api-svc` | Service selector matches zero pods |
| Service selector is `component: backend` | `kubectl get svc incident-api-svc -o yaml` or `kubectl describe svc` | Selector doesn't match pod labels |
| Pod labels include `component: api` | `kubectl get pods --show-labels` or `kubectl describe pod` | Pods have `api`, Service expects `backend` |
| Manifest says `component: api` | `cat manifests/api-service.yaml` | Source of truth shows correct selector |
| Port-forward to pod works | `kubectl port-forward pod/<pod> 8080:8200` | App is healthy, routing is the problem |

---

## Ideal diagnostic path (~8-10 commands)

```bash
curl -i localhost/api/v1/status                                 # 502 Bad Gateway — confirm symptom
kubectl get pods -n incident-mgmt                               # all 1/1 Running — pods are fine
kubectl get endpoints -n incident-mgmt                          # incident-api-svc has no endpoints
kubectl describe svc incident-api-svc -n incident-mgmt          # selector: component=backend, no endpoints listed
kubectl get pods -n incident-mgmt --show-labels                 # pods have component=api, not backend
cat manifests/api-service.yaml                                  # confirms selector should be component: api
kubectl apply -f manifests/api-service.yaml                     # restore correct selector
kubectl get endpoints incident-api-svc -n incident-mgmt         # endpoints now populated
curl -i localhost/api/v1/status                                 # 200
curl -i localhost/api/v1/incidents                               # returns data
```

---

## Narration guide — what to say out loud at each stage

**After reproducing the symptom (502):**
> "Getting a 502 Bad Gateway. That's nginx telling me it can't reach an upstream. Let me check if the pods are actually running."

**After `kubectl get pods` (all 1/1 Running):**
> "Pods are all Running and Ready, no restarts. So the app is healthy — the problem must be in how traffic gets routed to the pods. Let me check endpoints."

**After `kubectl get endpoints` (empty):**
> "The `incident-api-svc` endpoint has no addresses. That means the Service isn't matching any pods. This is a selector mismatch — the Service is looking for pods with labels that don't exist. Let me check the Service selector."

**After `kubectl describe svc` (selector: component=backend):**
> "The Service selector is `component: backend`. Let me check what labels the pods actually have."

**After `kubectl get pods --show-labels` (component=api):**
> "The pods have `component: api` but the Service is selecting `component: backend`. That's the mismatch — the Service can't find any pods. Let me check the manifest to confirm what the selector should be."

**After `cat manifests/api-service.yaml` (component: api):**
> "The manifest has `component: api` as the selector. The live Service was changed to `backend`. I'll re-apply the manifest to restore the correct selector."

**After fix and verification:**
> "Endpoints are populated again, and both `/api/v1/status` and `/api/v1/incidents` return 200 through Ingress. The root cause was the Service selector was changed from `component: api` to `component: backend`, so no pods matched and nginx had no upstream to forward to."

---

## What to watch for as assessor

### Good signs

- Sees pods are healthy and immediately shifts to the routing layer (endpoints, Service, Ingress)
- Checks endpoints early — recognises empty endpoints as the smoking gun
- Compares the Service selector against pod labels to confirm the mismatch
- Checks the manifest to find the intended selector (repo as source of truth)
- Uses `kubectl apply -f manifests/` to fix rather than ad-hoc patching
- Can explain the full chain: selector mismatch -> empty endpoints -> 502
- Verifies end-to-end after fix

### Amber flags

- Fixes with `kubectl patch svc ... -p '{"spec":{"selector":{"component":"api"}}}'` — correct but didn't use repo as source of truth
- Finds the mismatch but doesn't explain the causal chain (selector -> endpoints -> 502)
- Spends time checking Ingress configuration before checking Service/endpoints
- Doesn't port-forward to prove the app is healthy independently

### Red flags

- Sees pods Running and declares the system healthy without checking routing
- Tries to restart pods or the Deployment to fix a 502
- Doesn't check endpoints at all — jumps to Ingress config or NetworkPolicies
- Doesn't understand how Service selectors match pods to endpoints
- Tries to change pod labels to match the wrong selector instead of fixing the Service
- Can't explain what the 502 from nginx means

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Checks logs or probe config despite pods being healthy | Checks pods, sees they're fine, moves to routing | Immediately recognises 502 + healthy pods = routing layer issue |
| 2 | **Runtime flow** | Random commands, stuck at pod layer | Pods → endpoints → service → fix | Curl → pods → endpoints (empty) → describe svc (selector) → show-labels (mismatch) → manifest → apply → verify |
| 3 | **Signal reading** | Doesn't check endpoints | Spots empty endpoints | Spots empty endpoints AND traces cause to selector mismatch AND explains the 502 chain |
| 4 | **Hypothesis-driven** | "Let me restart the pods" | "Endpoints are empty so the selector must be wrong" | "502 means nginx has no upstream. Pods are healthy so the Service must not be finding them. Empty endpoints confirms it — let me compare selector to pod labels." |
| 5 | **Intentional commands** | 15+ commands, many at wrong layer | ~10 commands | ~8 commands, clean progression through the routing layer |
| 6 | **Smallest fix** | Deletes and recreates the Service | kubectl patch to fix the selector | kubectl apply -f manifests/ (repo as source of truth, one command) |
| 7 | **End-to-end verification** | Declares fixed when endpoints populate | Curls one endpoint | Curls both endpoints AND confirms endpoints are populated |
| 8 | **Communication** | Silent | Narrates findings | Explains the full chain: selector mismatch -> empty endpoints -> no upstream -> 502. Narrates throughout. |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "The pods are healthy. What layer sits between the pods and the Ingress?"

**Hint 2 (more specific):** "Check the endpoints for the Service. Are there any addresses listed?"

**Hint 3 (pointed):** "Compare the selector on the Service with the labels on the pods. Do they match?"
