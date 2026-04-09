# Scenario 07 - Networking / Service Routing

**Date/Time:** 2026-04-06 ~16:20-16:32 BST

## Symptom Presented

"The app was working fine but now they're getting 503 errors. They don't think anything changed recently."

## What Was Actually Broken

The `platform-drill-api` Service selector was changed from `app: platform-drill-api` to `app: platform-drill`. The truncated selector matched zero pods, so endpoints were empty and the nginx ingress controller returned 503.

## Failure Domain

Networking / Service routing

## Fix Succeeded

Yes. User patched the Service selector back to `app: platform-drill-api`.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | Full triage: get pods, pods -A, deploy -A, svc -A. Everything healthy except endpoints. |
| Intentional commands | Strong | describe svc → saw selector and empty endpoints. get pods --show-labels → found label mismatch. Textbook selector mismatch diagnosis. |
| Hypothesis-driven | Strong | Empty endpoints + healthy pods = selector mismatch. Compared selector against pod labels and found the difference immediately. |
| One fix at a time | Strong | Single kubectl patch svc. Clean. |
| End-to-end verification | Solid | Verified endpoints repopulated and port-forward worked. But no curl through Ingress to verify full external path. |
| Communication | N/A | Independent scenario, not coached. |

## Notable Good Commands

- `kubectl describe svc platform-drill-api` — found `Selector: app=platform-drill` and `Endpoints: <none>`
- `kubectl get pods --show-labels` — showed pods have `app=platform-drill-api`
- `kubectl patch svc platform-drill-api -p '{"spec":{"selector":{"app":"platform-drill-api"}}}'` — correct surgical fix
- `kubectl get endpoints platform-drill-api` — confirmed endpoints repopulated after fix
- `kubectl port-forward svc/platform-drill-api 8080:80` — verified Service routes correctly

## Unnecessary/Redundant Commands

- None — clean, efficient command sequence

## Missing

- No `curl localhost/` through Ingress after the fix — should always verify the full external path

## Suggested Narration

- After describe svc: "Selector is app=platform-drill but endpoints are empty. Let me check what labels the pods actually have."
- After show-labels: "Pods have app=platform-drill-api — the selector is truncated, missing -api. That's the mismatch. I'll patch the selector."
- After fix: "Endpoints are populated now. Let me verify end-to-end through Ingress."
