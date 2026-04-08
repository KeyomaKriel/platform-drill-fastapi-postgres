# Scenario 04 - Ingress / External Access

**Date/Time:** 2026-04-06 ~08:05-08:40 BST

## Symptom Presented

"The app is returning errors when they try to access it. It was fine yesterday."

## What Was Actually Broken

The Ingress `app-ingress` backend service port was changed from 80 to 8080. The `platform-drill-api` Service only exposes port 80 (targetPort 8000), so the nginx ingress controller couldn't route traffic and returned 503 errors.

## Failure Domain

Ingress / external access

## Fix Succeeded

Yes. User edited the Ingress to correct the backend port from 8080 to 80.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | Full triage with -A flags: ns, pods, deploy, svc, ingress, events sorted. Very thorough. |
| Intentional commands | Solid | Good sequence. Minor detour into describing a completed admission webhook job, but recovered quickly. |
| Hypothesis-driven | Strong | Events showed Ingress sync + nginx reload, connected to symptom timing. Went straight to describe ingress + port-forward isolation. |
| One fix at a time | Strong | Single Ingress edit. Clean. |
| End-to-end verification | Strong | All three curl endpoints individually after fix. Also ran them batched. |
| Communication | Needs Work | Coached scenario — narration not independently tested. |

## Notable Good Commands

- Full `-A` triage across pods, deploy, svc, ingress
- `kubectl describe ingress app-ingress -n drill` — immediately revealed `platform-drill-api:8080`
- `kubectl get endpoints` — confirmed Service routing healthy
- `kubectl port-forward` + `curl` — proved Service layer worked, isolating to Ingress
- All three curl endpoints individually after fix

## Unnecessary/Redundant Commands

- `kubectl describe pod ingress-nginx-admission-create-wnpzt` (twice, once without namespace) — completed admission webhook job, not relevant to runtime issues
- `kubectl top nodes` — Metrics API not available, no resource pressure signal

## Suggested Narration

- After events: "The Ingress was synced and nginx reloaded 15 minutes ago — that's when the errors started. Pods and services look healthy, so this is likely an Ingress configuration change. Let me describe the Ingress."
- After describe ingress: "The backend shows platform-drill-api:8080 but the Service is on port 80. That port doesn't exist on the Service — nginx can't route there. I'll fix the port to 80."
- After fix: "Port corrected to 80. Let me verify end-to-end with curl on all three endpoints."
