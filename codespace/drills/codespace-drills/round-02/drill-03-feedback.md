# Drill 03 (Round 02) — Feedback

**Date:** 2026-04-13
**App:** Django incident API (`drill-app-django`)
**Task type:** Single-fault debugging
**Failure domain:** Probe Failure (Tier 1)
**Injected fault:** Readiness probe path changed from `/api/v1/status` to `/api/v1/ready` (returns 404)
**Result:** Fixed successfully

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Solid | Started with get pods, spotted 0/1 on new pod. No curl first. |
| 2 | Runtime flow | Strong | Pods → describe (probe 404) → pod YAML → logs (healthy) → apply manifest → verify. |
| 3 | Signal reading | Strong | Found readiness 404 in Events. Noticed readiness vs liveness path mismatch. |
| 4 | Hypothesis-driven | Strong | Deliberately checked full pod YAML to confirm probe paths. |
| 5 | Intentional commands | Solid | ~10 commands. Pod YAML check was thorough but signal already clear from describe. |
| 6 | Smallest fix | Strong | kubectl apply -f manifests/api-deployment.yaml. |
| 7 | End-to-end verification | Strong | Pods 1/1, services checked, curled both endpoints. |
| 8 | Communication | N/A | Cannot assess from log alone. |

---

## Pattern across round 02

| Drill | Domain | Entry | Signal | Fix | Verification |
|-------|--------|-------|--------|-----|-------------|
| 01 | Config/Secret/Env | Solid | Strong | Strong | Strong |
| 02 | Service routing | Solid | Strong | Strong | Strong |
| 03 | Probe failure | Solid | Strong | Strong | Strong |

Consistent strengths: signal reading, source-of-truth fixes, full verification.
Consistent gap: reproduce symptom with curl before investigating.

---

## Failure domain coverage (Round 02, Django)

| # | Domain | Tier | Drill | Status |
|---|--------|------|-------|--------|
| 1 | Config / Secret / env | 1 | 01 | Done |
| 2 | Service routing / selector | 1 | 02 | Done |
| 3 | Probe failure | 1 | 03 | Done |
| 4 | Image pull failure | 1 | — | Next |
