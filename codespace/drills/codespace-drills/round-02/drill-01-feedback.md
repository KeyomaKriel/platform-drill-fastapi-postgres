# Drill 01 (Round 02) — Feedback

**Date:** 2026-04-13
**App:** Django incident API (`drill-app-django`)
**Task type:** Single-fault debugging
**Failure domain:** Config / Secret / Env (Tier 1)
**Injected fault:** Secret reference changed from `incident-api-credentials` to `incident-api-secrets` (doesn't exist)
**Result:** Fixed successfully

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Solid | Started with `get pods`, spotted `Init:CreateContainerConfigError`. |
| 2 | Runtime flow | Strong | Pods → describe → get secrets → describe deploy → apply manifest → verify. Clean path. |
| 3 | Signal reading | Strong | Found exact error in Events, identified wrong Secret name in envFrom, cross-referenced with existing Secrets. |
| 4 | Hypothesis-driven | Solid | Identified Secret reference mismatch, confirmed drift, fixed from manifest. |
| 5 | Intentional commands | Solid | ~10 commands. `describe deploy` and `get secret -o yaml` were thorough but not strictly necessary. |
| 6 | Smallest fix | Strong | `kubectl apply -f manifests/api-deployment.yaml` — source of truth. |
| 7 | End-to-end verification | Strong | Checked endpoints, curled `/api/v1/status` and `/api/v1/incidents` through Ingress. |
| 8 | Communication | N/A | Cannot assess from log alone. |

---

## Key improvements from previous rounds

- Started at the right layer (pods first, not ingress/services)
- Read describe output carefully — found the exact error and reference
- Cross-referenced before fixing (get secrets to confirm what exists)
- Used repo manifest as source of truth
- Verified fully (endpoints + multiple curl endpoints)

---

## Failure domain coverage (Round 02, Django)

| # | Domain | Tier | Drill | Status |
|---|--------|------|-------|--------|
| 1 | Config / Secret / env | 1 | 01 | Done |
| 2 | Probe failure | 1 | — | Next |
| 3 | Service routing / selector | 1 | — | — |
| 4 | Image pull failure | 1 | — | — |
