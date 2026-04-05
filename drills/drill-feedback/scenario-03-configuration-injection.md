# Scenario 03 - Configuration Injection

**Date/Time:** 2026-04-05 ~16:12-16:48 BST

## Symptom Presented

"We pushed a config update and restarted the app a few minutes ago. The app still seems to be responding, but we're seeing a new pod that keeps crashing. The deploy doesn't look like it's completing."

## What Was Actually Broken

The `app-config` ConfigMap was patched to change `POSTGRES_DB` from `platformdrill` to `platformdrill_v2`. The deployment was restarted, causing a rolling update. The new pod crashed on startup because the database `platformdrill_v2` does not exist in Postgres. The old pod continued serving traffic, masking the full impact.

## Failure Domain

Configuration injection

## Fix Succeeded

Yes. User edited the ConfigMap to correct `POSTGRES_DB` back to `platformdrill`, then restarted the deployment.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | Full triage: pods, deploy, svc, ingress, events (sorted and unsorted). Thorough and systematic. |
| Intentional commands | Strong | Describe pod -> logs -> identify error -> check ConfigMap -> fix. Clean logical chain with no wasted commands. |
| Hypothesis-driven | Strong | Logs showed "database platformdrill_v2 does not exist" — immediately went to ConfigMap to verify. Clear theory-to-action. |
| One fix at a time | Strong | Single ConfigMap edit, then rollout restart. Clean. |
| End-to-end verification | Strong | New pod Running 1/1, all three curl endpoints return valid responses. |
| Communication | Needs Work | Coached scenario — narration not independently tested. User should practice verbalizing the reasoning chain without prompting. |

## Notable Good Commands

- `kubectl logs` on the crashing pod — found the exact error (`database "platformdrill_v2" does not exist`)
- `kubectl get configmap` then `kubectl edit configmap app-config` — went straight to the source
- Used nvim autocomplete to select correct value efficiently
- `kubectl rollout restart` after ConfigMap edit — understood that envFrom doesn't auto-reload

## Unnecessary/Redundant Commands

- `$errorPod = "..."` — PowerShell syntax in zsh shell; use `export` or type the pod name directly
- Clipboard paste accident dumped unrelated notes into terminal — be careful with clipboard management in interview settings

## Suggested Narration

- After seeing CrashLoopBackOff: "New pod is crashing with exit code 1 — that's an application error, not OOMKill. Let me check the logs."
- After reading the logs: "The app says database 'platformdrill_v2' doesn't exist. That's a config problem — the POSTGRES_DB value is wrong. Let me check the ConfigMap."
- After seeing the ConfigMap: "Confirmed — POSTGRES_DB is set to 'platformdrill_v2' but the actual database is 'platformdrill'. I'll fix the ConfigMap and restart the deployment since envFrom doesn't pick up changes automatically."
- After fix: "New pod is up. Let me curl all three endpoints to confirm end-to-end."
