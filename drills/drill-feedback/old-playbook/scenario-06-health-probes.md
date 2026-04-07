# Scenario 06 - Health Probes

**Date/Time:** 2026-04-06 ~11:30-16:30 BST (interrupted by playbook work, resumed)

## Symptom Presented

"We pushed an update but the rollout doesn't seem to be completing. The app is still responding but we're not sure if the new version is actually live."

## What Was Actually Broken

The deployment's `readinessProbe.httpGet.path` was changed from `/health` to `/ready`. The app does not expose a `/ready` endpoint, so the probe returned 404 on every check. The new pod stayed `Running 0/1` (not Ready), the rolling update was stuck with `ProgressDeadlineExceeded`, and the old pod continued serving traffic.

## Failure Domain

Health probes

## Fix Succeeded

Yes. User edited the deployment to change the readiness probe path back to `/health`.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | Identified the 0/1 pod immediately from `get pods`. |
| Intentional commands | Strong | `describe pod` found probe failure with 404. `get pod -o json` read the full probe spec. `get deploy -o json` found the original probe path in `last-applied-configuration` annotation. |
| Hypothesis-driven | Strong | Correctly identified `/ready` as wrong. Found the correct value `/health` through two independent methods: last-applied-configuration annotation and the liveness probe on the same pod. |
| One fix at a time | Strong | Single deployment edit. First attempt cancelled (inspected without saving), second attempt applied the fix. |
| End-to-end verification | Needs Work | No curl commands after the fix in the session log. Confirmed with get pods/rs/rollout status but did not verify external traffic. |
| Communication | Solid | Excellent questions during coaching about how to discover the correct probe path. |

## Notable Good Commands

- `kubectl describe pod <broken-pod>` — found `Readiness probe failed: HTTP probe failed with statuscode: 404`
- `kubectl get pod <broken-pod> -o json` — read the full readiness probe spec
- `kubectl get deploy platform-drill-api -o json` — found `last-applied-configuration` annotation showing original probe path was `/health`
- `kubectl get pod <broken-pod> -o jsonpath='{.spec.containers[0].readinessProbe}'` — confirmed current probe is `/ready`
- `kubectl edit deploy platform-drill-api` — changed probe path to `/health`

## Unnecessary/Redundant Commands

- `kubectl port-forward pod/<broken-pod> 8080:80` — used wrong port (80 instead of 8000)
- `kubectl edit configmap app-config` — opened and cancelled; the problem was in the probe, not the config
- First `kubectl edit deploy` — opened and cancelled without changes

## Missing

- No curl verification after the fix
- No port-forward test to discover what paths the app actually serves (would have confirmed `/health` returns 200)

## Key Learning

- When a readiness probe returns 404, the diagnostic dead-end is: you know the probe path is wrong, but you don't know what the correct path should be
- Methods to find the correct path: (1) check the old/working pod's probe spec, (2) check the `last-applied-configuration` annotation, (3) port-forward and curl to discover what paths return 200, (4) compare the liveness probe (which was still set to `/health`)
- This scenario drove a significant playbook improvement: the readiness probe sub-branch now includes commands to read the probe config, discover app paths, and compare old vs new pod specs

## Suggested Narration

- After seeing 0/1: "The new pod is Running but not Ready — the readiness probe is failing. Let me check what the probe is set to and what it's getting back."
- After finding 404: "The probe is hitting /ready on port 8000 and getting a 404. That path doesn't exist on the app. I need to find what path the app actually serves."
- After finding /health: "The liveness probe uses /health and the last-applied-configuration shows the readiness probe was also /health before this change. I'll fix the readiness probe path back to /health."
- After fix: "The new pod should become Ready now. Let me watch the rollout and then curl all three endpoints to confirm end-to-end."
