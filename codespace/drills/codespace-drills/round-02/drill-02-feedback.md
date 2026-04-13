# Drill 02 (Round 02) — Feedback

**Date:** 2026-04-13
**App:** Django incident API (`drill-app-django`)
**Task type:** Single-fault debugging
**Failure domain:** Service Routing / Port / Endpoint (Tier 1)
**Injected fault:** Service selector changed from `component: api` to `component: backend` — empty endpoints
**Result:** Fixed successfully

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Solid | Repo orientation (tree) then pods then endpoints. No curl first. |
| 2 | Runtime flow | Strong | Pods → endpoints (empty) → describe svc → show-labels → apply manifest → verify. |
| 3 | Signal reading | Strong | Spotted empty endpoints immediately. Found selector mismatch. |
| 4 | Hypothesis-driven | Solid | Correctly identified selector mismatch, compared against pod labels. |
| 5 | Intentional commands | Solid | ~12 commands. One unnecessary Deployment apply before fixing the Service. |
| 6 | Smallest fix | Strong | `kubectl apply -f manifests/api-service.yaml` — source of truth. |
| 7 | End-to-end verification | Strong | Endpoints + curl both endpoints through Ingress. |
| 8 | Communication | N/A | Cannot assess from log alone. |

---

## Pattern across round 02

| Drill | Domain | Entry mode | Signal reading | Fix approach | Verification |
|-------|--------|-----------|----------------|--------------|-------------|
| 01 | Config/Secret/Env | Solid (pods first) | Strong | Strong (apply manifest) | Strong |
| 02 | Service routing | Solid (tree + pods) | Strong (empty endpoints) | Strong (apply manifest) | Strong |

Consistent improvements from round 01:
- Starting at the right layer
- Strong signal reading once at the right layer
- Using repo manifests as source of truth
- Full end-to-end verification

Remaining area: reproduce symptom with curl before investigating.

---

## Failure domain coverage (Round 02, Django)

| # | Domain | Tier | Drill | Status |
|---|--------|------|-------|--------|
| 1 | Config / Secret / env | 1 | 01 | Done |
| 2 | Service routing / selector | 1 | 02 | Done |
| 3 | Probe failure | 1 | — | Next |
| 4 | Image pull failure | 1 | — | — |
