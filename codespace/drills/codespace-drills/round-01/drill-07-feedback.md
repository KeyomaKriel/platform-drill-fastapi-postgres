# Drill 07 — Feedback

**Date:** 2026-04-11
**App:** Go inventory API (`drill-app-go`)
**Task type:** Single-fault debugging
**Failure domain:** Ingress / external routing failure (Tier 2)
**Injected fault:** `ingressClassName` changed from `nginx` to `traefik`
**Result:** Fixed successfully

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Solid | Started with `get pods`. Didn't reproduce symptom with curl first. |
| 2 | Runtime flow | Solid | Pods → port-forward → services → ingress → describe → fix. Logical layer-by-layer narrowing. |
| 3 | Signal reading | Strong | Spotted `CLASS: traefik` in ingress output and recognised the mismatch. |
| 4 | Hypothesis-driven | Solid | Port-forward proved app healthy internally, correctly narrowing to Ingress layer. |
| 5 | Intentional commands | Solid | ~14 commands. Port-forward detour useful but added steps. Some duplicate curls. |
| 6 | Smallest fix | Strong | `kubectl apply -f manifests/ingress.yaml` — repo as source of truth. |
| 7 | End-to-end verification | Needs Work | Only curled `/` after fix. Didn't verify `/readyz` or `/api/v1/products`. |
| 8 | Communication | N/A | Cannot assess from log alone. |

---

## Key observations

**Good:** Port-forward to isolate the problem layer. Checked endpoints. Checked ingress-nginx controller health. Used canonical manifest to fix.

**Improve:** Reproduce symptom first (curl before investigating). Verify all endpoints after fix. Know your working directory to avoid path fumbles.

---

## Failure domain coverage

| # | Domain | Tier | Drill | Status |
|---|--------|------|-------|--------|
| 1 | Config / Secret / env | 1 | 02 | Done |
| 2 | Probe failure | 1 | 03 | Done |
| 3 | Service routing / selector | 1 | 04 | Done |
| 4 | Image pull failure | 1 | 06 | Done |
| 5 | App dependency (DB down) | 2 | 05 | Done |
| 6 | Ingress / external routing | 2 | 07 | Done |
| 7 | Startup / crash failure | 2 | — | Next |
