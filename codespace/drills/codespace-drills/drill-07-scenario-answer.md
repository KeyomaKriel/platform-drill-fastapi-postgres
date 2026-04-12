# Drill 07 — Debugging Answer Key (Assessor Copy)

**App:** Go inventory API (`drill-app-go`)
**Failure domain:** Ingress / external routing failure (Tier 2)
**Injected fault:** The Ingress resource's `ingressClassName` was changed from `nginx` to `traefik` — a class that doesn't exist in this cluster. The nginx Ingress controller stops serving the Ingress because it no longer matches its watch filter.

---

## What will happen after injection

- All pods remain Running/Ready (the fault is at the Ingress layer, not pod/service layer)
- Services and endpoints remain healthy and populated
- `curl localhost/` returns 404 from the nginx Ingress controller's default backend (no matching Ingress rule)
- Direct pod or service access still works (e.g. `kubectl port-forward`, `kubectl exec ... -- curl`)
- `kubectl get ingress -n warehouse-sys` shows the Ingress exists but the ADDRESS field may be empty or stale
- `kubectl describe ingress` shows `ingressClassName: traefik` instead of `nginx`

This fault is tricky because the candidate must trace the request path beyond pod and service health. Everything below the Ingress layer is fine.

---

## Key signals the candidate should find

| Signal | Where | What it means |
|--------|-------|---------------|
| Pods `1/1 Running` and Ready | `kubectl get pods -n warehouse-sys` | Problem is not at pod level |
| Endpoints populated | `kubectl get endpoints -n warehouse-sys` | Service routing is correct |
| `curl localhost/` returns 404 | Terminal | Ingress not routing to backend |
| `ingressClassName: traefik` | `kubectl get ingress -o yaml` or `kubectl describe ingress` | Wrong Ingress class |
| Only `nginx` IngressClass exists | `kubectl get ingressclass` | No `traefik` controller installed |
| Manifest says `ingressClassName: nginx` | `cat manifests/ingress.yaml` | Source of truth shows correct class |
| Direct pod access works | `kubectl port-forward` or `kubectl exec` | Confirms app is healthy, problem is Ingress |

---

## Ideal diagnostic path (~8-10 commands)

```bash
kubectl get pods -n warehouse-sys              # all Running/Ready — not a pod issue
kubectl get svc -n warehouse-sys               # services exist
kubectl get endpoints -n warehouse-sys         # endpoints populated — not a service issue
curl localhost/readyz                           # 404 — external routing broken
curl localhost/api/v1/products                  # 404 — confirms Ingress not routing
kubectl get ingress -n warehouse-sys            # Ingress exists, check CLASS column
kubectl describe ingress inventory-api-ingress -n warehouse-sys  # see ingressClassName: traefik
kubectl get ingressclass                        # only 'nginx' exists — no traefik
cat manifests/ingress.yaml                      # confirms it should be 'nginx'
kubectl apply -f manifests/ingress.yaml         # restore correct ingressClassName
curl localhost/readyz                           # 200 — fixed
curl localhost/api/v1/products                  # returns product data
```

---

## What to watch for as assessor

### Good signs

- Checks pods AND services/endpoints early — doesn't stop at "pods are fine"
- Tests external access with curl to confirm the symptom
- Inspects the Ingress resource specifically (describe or get -o yaml)
- Recognises `ingressClassName: traefik` doesn't match the installed controller
- Checks what IngressClasses are available (`kubectl get ingressclass`)
- Compares live Ingress with the manifest to find the discrepancy
- Uses `kubectl apply -f manifests/ingress.yaml` to fix (repo as source of truth)
- Verifies end-to-end with curl after fix
- Narrates: "The pods and services are fine, so the problem must be in the Ingress layer"

### Amber flags

- Fixes with `kubectl edit ingress` or `kubectl patch` — correct but didn't use repo as source of truth
- Checks the Ingress but doesn't verify what IngressClasses exist in the cluster
- Takes a long time to get past pod/service checks before looking at Ingress
- Doesn't test external access early — debugs blind without reproducing the symptom

### Red flags

- Tries to install Traefik to fix it (solving the wrong problem)
- Restarts pods or deployments hoping it fixes the routing
- Never checks the Ingress resource — stays at the pod/service layer the entire time
- Deletes and recreates the Ingress without understanding why it broke
- Can't explain what an IngressClass is or how the Ingress controller selects which resources to serve

---

## Evaluation criteria

| # | Criteria | Needs Work | Solid | Strong |
|---|----------|-----------|-------|--------|
| 1 | **Entry mode** | Jumps to pod logs without checking external access | Checks pods, then services, then ingress | Reproduces symptom first (curl), then systematically works inward |
| 2 | **Runtime flow** | Random commands, doesn't progress beyond pods | Pods → services → ingress → identifies class mismatch | Curl → pods (healthy) → endpoints (fine) → ingress (wrong class) → fix, clean progression |
| 3 | **Signal reading** | Doesn't look at Ingress, or looks but misses the class | Spots wrong ingressClassName in describe output | Spots it AND checks what classes exist in the cluster to confirm |
| 4 | **Hypothesis-driven** | Tries random restarts or config changes | "Pods are fine, service has endpoints, must be ingress" | "External access fails but internal is fine — this is an Ingress-layer issue, let me check the Ingress resource" |
| 5 | **Intentional commands** | 15+ commands, detours into configmaps/secrets | ~12 commands, mostly on target | ~8-10 commands, no wasted steps |
| 6 | **Smallest fix** | Tries to install Traefik or edit multiple resources | kubectl edit/patch to fix the class | kubectl apply -f manifests/ingress.yaml (repo as source of truth) |
| 7 | **End-to-end verification** | Declares fixed after seeing Ingress updated | Curls one endpoint | Curls both /readyz and /api/v1/products |
| 8 | **Communication** | Silent or only speaks when stuck | Narrates key findings and decisions | Narrates throughout: symptom reproduction, ruling out layers, identifying root cause |

---

## Hints (if candidate asks)

**Hint 1 (directional):** "If the pods and services are healthy, what else sits in the request path?"

**Hint 2 (more specific):** "Take a close look at the Ingress resource — is the controller picking it up?"

**Hint 3 (pointed):** "Check what IngressClasses are available in the cluster and compare with what the Ingress is configured to use."
