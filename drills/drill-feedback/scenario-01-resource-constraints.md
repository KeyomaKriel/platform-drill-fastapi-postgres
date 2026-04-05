# Scenario 01 - Resource Constraints

**Date/Time:** 2026-04-05 ~13:43-14:16 BST

## Symptom Presented

"The app keeps restarting and we're not sure why. It was working fine earlier today."

## What Was Actually Broken

Memory limit lowered to 8Mi (requests to 4Mi) on the `platform-drill-api` deployment. The FastAPI container was immediately OOMKilled (exit code 137) on every startup attempt, causing CrashLoopBackOff.

## Failure Domain

Resource constraints

## Fix Succeeded

Yes. User raised memory limits back to 128Mi/64Mi via `kubectl edit deploy platform-drill-api`.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Solid | Started with `get ns`, set namespace, then `get pods` to see the broken pod. Did not run full universal triage (`get all`, `get events`, etc.) but found the signal quickly. |
| Intentional commands | Solid | Commands followed a logical path: get pods -> describe pod -> logs -> edit deploy. Each step built on the previous finding. |
| Hypothesis-driven | Needs Work | Did not articulate a hypothesis at any point. The OOMKilled signal was clear, but user didn't verbalize the connection between exit code 137, the 8Mi limit, and the fix needed. |
| One fix at a time | Strong | Single edit to the deployment, fixing both memory requests and limits in one pass. Clean. |
| End-to-end verification | Needs Work | Verified pods were Running and checked logs of the healthy pod, but did not curl the app endpoints to confirm full end-to-end functionality. |
| Communication | Needs Work | No narration observed in the session log. In an interview, thinking out loud is critical. |

## Notable Commands

**Good:**
- `kubectl describe pod <pod>` immediately after seeing CrashLoopBackOff - correct instinct
- `kubectl edit deploy` to fix the resource limits directly

**Unnecessary/Redundant:**
- `kubectl top pod` - failed because Metrics API not available; 8-minute gap afterward suggests the user stalled
- `kubectl logs` returned empty twice on the crashing pod without narrating why (OOMKill before any output)
- Typo command `KUBE_EDITOR=nano kubectl edit deploykubectl get deploy` wasted time
- Described and checked logs of the *healthy old pod* after fixing - not wrong, but the priority should have been curling the endpoints

## Suggested Narration

- After `get pods`: "I see CrashLoopBackOff with a high restart count on the new pod. The old pod is still Running. Let me describe the crashing pod to find out why."
- After `describe pod`: "Exit code 137, reason OOMKilled. The container is being killed for exceeding its memory limit. The limit is only 8Mi - that's way too low for a Python/FastAPI app. I need to raise it."
- After empty logs: "Logs are empty because the process is killed before it can write any output. That's consistent with OOMKill."
- After fix: "Fix applied. Let me verify end-to-end - not just that pods are Running, but that I can actually reach the app and get valid responses from all endpoints."
