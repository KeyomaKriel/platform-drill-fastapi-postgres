# Drill 11 — Feedback

**Date:** 2026-04-13
**App:** Django incident API (`drill-app-django`)
**Task type:** Single-fault debugging
**Failure domain:** Service Routing / Port / Endpoint (Tier 1)
**Injected fault:** Service selector changed from `component: api` to `component: backend` — empty endpoints, 502 from Ingress
**Result:** Fixed successfully (eventually)

---

## Evaluation

| # | Criteria | Rating | Notes |
|---|----------|--------|-------|
| 1 | Entry mode | Needs Work | No curl to reproduce symptom first. Jumped to `describe svc`. |
| 2 | Runtime flow | Needs Work | Skipped pods and endpoints, went straight to Service describe. |
| 3 | Signal reading | Solid | Spotted selector mismatch after comparing with `--show-labels`. |
| 4 | Hypothesis-driven | Solid | Correctly identified "service selector is incorrect." |
| 5 | Intentional commands | Solid | Reasonable command count, but didn't investigate why first `apply` failed. |
| 6 | Smallest fix | Needs Work | First `apply` didn't work — didn't investigate the merge behaviour. |
| 7 | End-to-end verification | N/A | Not visible in pasted output. |
| 8 | Communication | N/A | Cannot assess from pasted output alone. |

---

## Key learning: kubectl apply merge semantics

The break patched the Service selector from `{component: api}` to `{component: backend}`. The patch command used `kubectl patch -p '{"spec":{"selector":{"component":"backend"}}}'` which **added/changed** the `component` key but the underlying merge also introduced `app=api` as a selector key.

When `kubectl apply -f manifests/api-service.yaml` was run, it restored `component: api` but did NOT remove the extra `app=api` key. This is because `kubectl apply` merges map fields — it doesn't strip keys that aren't in the manifest.

Result: selector became `app=api,component=api` — pods only have `component=api`, not `app=api`, so still zero matches.

**Takeaway:** If a patch added a key the manifest doesn't mention, `apply` won't remove it. Use `kubectl replace -f` to fully replace the resource spec, or manually remove the extra key with `kubectl edit` or a targeted patch.

---

## Pattern across recent drills

- Consistently skipping symptom reproduction (curl) as the first step
- Strong signal reading once at the right layer
- Uses repo manifests to fix (good instinct)
- New learning needed: `kubectl apply` merge behaviour vs `kubectl replace`

---

## Failure domain coverage (Django app)

| # | Domain | Tier | Drill | Status |
|---|--------|------|-------|--------|
| 1 | Image pull failure | 1 | 09 | Done |
| 2 | Probe failure | 1 | 10 | Done |
| 3 | Service routing / selector | 1 | 11 | Done |
| 4 | Config / Secret / env | 1 | — | Next |
