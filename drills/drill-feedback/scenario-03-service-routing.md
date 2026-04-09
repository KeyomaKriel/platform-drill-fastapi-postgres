# Scenario 03 — Service Routing / Port / Endpoint Failure (Debugging)

**Date:** 2026-04-08 16:02–16:18
**Task type:** Single-fault debugging
**Failure domain:** Service routing / port / endpoint failure (Tier 1)
**Injected fault:** Service selector changed from `app: platform-drill-api` to `app: platform-drill`
**Result:** Fixed successfully in ~16 min

## Prompt given

> A colleague on another team just pinged you: "Hey, can you take a look at your service? We're trying to hit it and something seems off."

## What was required

Identify the selector mismatch between the service (`app: platform-drill`) and the pod label (`app: platform-drill-api`), fix the selector, and verify end-to-end.

## Evaluation

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Entry mode | Strong | Broad triage in first minute |
| Runtime flow | Solid | Good progression with port-forward isolation detour |
| Signal reading | Strong | Spotted empty endpoints immediately, used port-forward to prove pod health |
| Hypothesis-driven | Strong | Empty endpoints + healthy pod → selector issue → confirmed |
| Intentional commands | Solid | Port-forward isolation was smart |
| Smallest justified fix | Strong | Single kubectl patch |
| End-to-end verification | Needs Work | Port-forward and endpoints checked, but no curl through ingress |
| Communication | Needs Work | No narration visible |

## Notable good actions

- Set default namespace early to avoid -n drill repetition
- Port-forward to pod (8000) proved pod was healthy, isolating fault to service layer
- Cross-referenced describe svc selector with pod labels
- Used kubectl patch for minimal fix

## Unnecessary/redundant actions

- First port-forward attempt to port 80 (container listens on 8000) — reading the deployment spec or service targetPort would have avoided this
- kubectl events check — low value for a selector mismatch (no events generated)

## Suggested narration at key decision points

- After endpoints show <none>: "Both pods are Running and Ready, but the app service has no endpoints. That means the service selector isn't matching any pods. Let me check the selector."
- After describe svc: "The selector is 'app=platform-drill' but the pod label is 'app=platform-drill-api'. That's the mismatch. I'll patch the selector."
- After fix: "Endpoints are populated now. Let me curl through the ingress to prove the full path works — localhost/, /health, and /items."
