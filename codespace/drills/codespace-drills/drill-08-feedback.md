# Drill 08 — Feedback

**Date:** 2026-04-12
**App:** Go inventory API (`drill-app-go`)
**Task type:** Single-fault debugging
**Failure domain:** Startup / crash failure (Tier 2)
**Injected fault:** Container command overridden to `./inventory-service` (binary doesn't exist)
**Result:** Fixed successfully via `kubectl rollout undo`

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Solid | Checked context and cluster state. Didn't start with pods despite "not coming up" symptom. |
| 2 | Runtime flow | Needs Work | 7 commands (ingress, svc, endpoints, port-forward) before first `get pods`. Symptom pointed to pod layer. |
| 3 | Signal reading | Strong | Read the exec error clearly. Compared crashing vs healthy pod. Found the command override in deployment YAML. |
| 4 | Hypothesis-driven | Solid | Good differential diagnosis between old and new pods. Checked deployment YAML to confirm. |
| 5 | Intentional commands | Needs Work | ~20+ commands. Detours into ConfigMap, port-forward to crashing pod. `apply` returned `unchanged` without follow-up. |
| 6 | Smallest fix | Solid | `rollout undo` was correct once `apply` didn't work. |
| 7 | End-to-end verification | Solid | Curled through Ingress after fix. Didn't verify `/api/v1/products`. |
| 8 | Communication | N/A | Cannot assess from log alone. |

---

## Key observations

**Good:** Differential diagnosis comparing crashing and healthy pods. Read full deployment YAML. Adapted to `rollout undo` when `apply` failed. Resourceful recovery.

**Improve:**
1. Match entry mode to symptom — "not coming up" means check pods first, not ingress/services.
2. Understand why `kubectl apply` returned `unchanged` (annotation-based diff tracking vs runtime patches).
3. Don't port-forward to a crashing pod or check ConfigMaps when the error says "no such file or directory."
4. Let the error message direct your next command — tighter signal-to-action loop.

---

## Pattern across drills 07-08

- Both times: entered at the service/ingress layer before looking at the layer the symptom pointed to.
- Both times: strong signal reading once you got to the right layer.
- Both times: used repo manifest or rollout history to fix (good instinct).
- Improvement area: reproduce symptom first (curl), then let the symptom guide which layer to investigate.

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
| 7 | Startup / crash failure | 2 | 08 | Done |
| 8 | NetworkPolicy / traffic restriction | 3 | — | Next (if requested) |
