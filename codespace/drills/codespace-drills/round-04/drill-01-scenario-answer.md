# Drill 01 — Answer Key (Assessor Only)

**Round:** 04
**Drill:** 01
**Task type:** Single-fault debugging
**Failure domain:** Ingress / external routing (Tier 2)
**App:** drill-app-django
**Namespace:** incident-mgmt

---

## Injected Fault

The Ingress resource `incident-api-ingress` had its `ingressClassName` changed from `nginx` to `traefik` in the manifest file, then reapplied.

**Injection commands (run via SSH on the Codespace):**

```bash
sed -i 's/ingressClassName: nginx/ingressClassName: traefik/' /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/manifests/ingress.yaml
kubectl apply -f /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django/manifests/ingress.yaml -n incident-mgmt
```

**What changed:** The Ingress resource now references `ingressClassName: traefik`, which does not exist in the cluster. The nginx Ingress controller only watches for Ingress resources with `ingressClassName: nginx`, so it stops serving this Ingress. The nginx default backend returns 404 for any request that no longer matches a known Ingress rule.

---

## What Happens

| Layer | Status |
|---|---|
| Pods | All Running and Ready (app + postgres) |
| Service | `incident-api-svc` healthy, endpoints populated |
| Endpoints | Populated with pod IPs |
| Ingress | Exists but has no ADDRESS assigned (nginx controller ignores it) |
| External curl | Returns **404** from the nginx default backend |
| Pod-level curl (via `kubectl exec`) | App responds normally on port 8000 |

The key misdirection: everything below the Ingress layer is perfectly healthy. The 404 comes from the nginx default backend, not the application, which can confuse candidates into thinking it is an app routing issue.

---

## Key Signals

| Signal | Where to find it | What it means |
|---|---|---|
| `curl` returns 404 | `curl -v http://localhost/` or Codespace port URL | Request reaches nginx but no Ingress rule matches |
| Ingress has no ADDRESS | `kubectl get ingress -n incident-mgmt` | The nginx controller is not reconciling this Ingress |
| `ingressClassName: traefik` | `kubectl get ingress incident-api-ingress -n incident-mgmt -o yaml` | Ingress references a non-existent IngressClass |
| No `traefik` IngressClass | `kubectl get ingressclass` | Only `nginx` IngressClass exists in the cluster |
| Manifest file differs from expected | `cat manifests/ingress.yaml` shows `traefik` | The fault is also persisted in the workspace file |
| Pods and service healthy | `kubectl get pods,svc,endpoints -n incident-mgmt` | Rules out app-level and service-level issues |
| App responds inside cluster | `kubectl exec -n incident-mgmt deploy/incident-api -- curl -s localhost:8000/` | Confirms the app itself is fine |

---

## Ideal Diagnostic Path

### 1. Orient and confirm the symptom (~1 min)

```bash
# Confirm external access fails
curl -v http://localhost/
# Expected: 404 from nginx default backend

# Quick cluster overview
kubectl get pods,svc,endpoints,ingress -n incident-mgmt
```

**Say:** "I can see the curl is returning a 404. Let me check the overall state of the namespace to see what's running."

### 2. Verify pods and service are healthy (~1 min)

```bash
kubectl get pods -n incident-mgmt
kubectl get endpoints -n incident-mgmt
```

**Say:** "Pods are all Running and Ready, and endpoints are populated. So the app and service layer look fine. The 404 is coming from the Ingress layer, not the app."

### 3. Inspect the Ingress resource (~2 min)

```bash
kubectl get ingress -n incident-mgmt
kubectl describe ingress incident-api-ingress -n incident-mgmt
kubectl get ingress incident-api-ingress -n incident-mgmt -o yaml
```

**Say:** "The Ingress exists but I notice it has no ADDRESS assigned. Let me look at the spec more closely... It says `ingressClassName: traefik`. That doesn't look right."

### 4. Check available IngressClasses (~1 min)

```bash
kubectl get ingressclass
```

**Say:** "There's only an `nginx` IngressClass available. There's no `traefik` class, so the nginx controller is ignoring this Ingress entirely. That explains why external requests get a 404 — no rule is matching."

### 5. Check the manifest file (~1 min)

```bash
cat manifests/ingress.yaml | grep -i ingressclass
```

**Say:** "The manifest file also has `traefik` in it. I need to fix both the manifest and the live resource."

### 6. Fix (~1 min)

```bash
# Edit the manifest file
sed -i 's/ingressClassName: traefik/ingressClassName: nginx/' manifests/ingress.yaml

# Apply the fix
kubectl apply -f manifests/ingress.yaml -n incident-mgmt
```

### 7. Verify end-to-end (~1 min)

```bash
kubectl get ingress -n incident-mgmt
# Should now show an ADDRESS

curl http://localhost/
curl http://localhost/health
curl http://localhost/api/incidents/
```

**Say:** "The Ingress now has an ADDRESS and all the endpoints are responding correctly. The issue was that the ingressClassName was set to traefik, which doesn't exist, so the nginx controller wasn't serving the Ingress."

---

## Assessor Guidance

### What makes this tricky

- Pods, service, and endpoints are all completely healthy — candidates who only check pod status may declare "everything looks fine."
- The 404 comes from the nginx default backend, which can be confused with an application-level 404.
- Candidates need to understand that an Ingress controller only reconciles Ingress resources that match its IngressClass.
- The missing ADDRESS on the Ingress is a subtle but critical signal.

### Common mistakes

- Spending time debugging the app or service when the 404 is at the Ingress layer.
- Restarting pods or redeploying the app (won't help).
- Not checking `kubectl get ingressclass` to confirm what's available.
- Fixing the live resource with `kubectl edit` or `kubectl patch` but not fixing the manifest file.
- Not verifying end-to-end after fixing.

### Red flags

- Not recognising the 404 is from the nginx default backend (check response headers).
- Never inspecting the Ingress resource.
- Guessing at fixes without reading the Ingress spec.

---

## Evaluation Criteria

| Criterion | Needs Work | Solid | Strong |
|---|---|---|---|
| **Entry mode** | Jumped straight to pod logs | Checked pods and service first, then Ingress | Systematic top-down: confirmed symptom, checked all layers, narrowed to Ingress quickly |
| **Runtime flow** | Skipped Ingress inspection | Followed a logical sequence to the Ingress layer | Efficient path: symptom → quick health check → Ingress inspection → IngressClass check → fix |
| **Signal reading** | Missed the missing ADDRESS or the wrong ingressClassName | Found the wrong ingressClassName | Noticed missing ADDRESS first, then confirmed with ingressClassName and `kubectl get ingressclass` |
| **Hypothesis-driven** | Tried random fixes (restart pods, redeploy) | Formed a theory about the Ingress before fixing | Articulated "The 404 is from the default backend, not the app, so the Ingress isn't being served" |
| **Intentional commands** | Ran commands without clear purpose | Each command had a reason | Could explain why each command was run and what they expected to see |
| **Smallest fix** | Deleted and recreated resources unnecessarily | Fixed the ingressClassName | Fixed the manifest file and applied — minimal change |
| **End-to-end verification** | Stopped after applying the fix | Checked curl returns 200 | Verified all endpoints (/, /health, /api/incidents/) and confirmed Ingress has ADDRESS |
| **Communication** | Silent debugging | Narrated key findings | Clear narration throughout: "The 404 is from the Ingress layer... the className is wrong... only nginx exists..." |

---

## Hints (if candidate is stuck)

**Hint 1 (gentle direction):** "The pods seem healthy. Where else in the request path could the 404 be coming from?"

**Hint 2 (more specific):** "Take a closer look at the Ingress resource. Is the nginx controller actually serving it?"

**Hint 3 (strong nudge):** "Check what IngressClasses are available in the cluster, and compare that to what the Ingress resource is requesting."

---

## Fix Summary

| What | Before | After |
|---|---|---|
| `manifests/ingress.yaml` → `spec.ingressClassName` | `traefik` | `nginx` |
| Live Ingress resource | `ingressClassName: traefik` (no ADDRESS) | `ingressClassName: nginx` (ADDRESS assigned) |
