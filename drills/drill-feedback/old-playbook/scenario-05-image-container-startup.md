# Scenario 05 - Image / Container Startup

**Date/Time:** 2026-04-06 ~11:25-12:14 BST

## Symptom Presented

"A teammate tagged a new version of the app and updated the deployment, but the new pods aren't coming up. The old version is still running."

## What Was Actually Broken

The deployment image was changed from `platform-drill-api:local` to `platform-drill-api:latest` via `kubectl set image`. Since the deployment has `imagePullPolicy: Never` (required for kind clusters where images are loaded locally), and the `latest` tag was never loaded into the kind node, the new pod failed with `ErrImageNeverPull`. The rolling update was stuck — old pod still serving, new pod unable to start.

## Failure Domain

Image / container startup

## Fix Succeeded

Yes. User rolled back the deployment with `kubectl rollout undo deploy/platform-drill-api`.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | `get pods -A`, `get deploy`, `describe deploy` — found the signal fast and got full deployment picture. |
| Intentional commands | Strong | `describe deploy` showed image tag, stuck rollout (ProgressDeadlineExceeded), and both ReplicaSets. `describe pod` confirmed image error. |
| Hypothesis-driven | Strong | Asked the right questions: what's the working tag, how to find it, what does rollback revert, what if other changes are intentional. Shows real understanding of trade-offs. |
| One fix at a time | Strong | Single `rollout undo`. Clean. |
| End-to-end verification | Solid | Verified with `get pods`, `get rs`, `rollout status`. But no curl tests — deployment looks healthy but didn't confirm app responds through Ingress. |
| Communication | Strong | Questions asked during coaching were exactly the reasoning an interviewer wants to hear. Demonstrated understanding of rollback vs set image trade-offs. |

## Notable Good Commands

- `kubectl get pods -A` — saw `ErrImageNeverPull` immediately
- `kubectl describe deploy` — found image tag, rollout status, ReplicaSet state in one command
- `kubectl describe pod` on failing pod — confirmed image pull error
- `kubectl rollout undo` — correct fix
- `kubectl get rs` — verified bad RS scaled to 0, good RS at 1/1
- `kubectl rollout status` — confirmed successful rollout

## Unnecessary/Redundant Commands

- None — clean command sequence

## Missing

- No curl verification (`localhost/`, `/health`, `/items`). Always finish with end-to-end proof.

## Suggested Narration

- After seeing ErrImageNeverPull: "The new pod can't pull its image. The status is ErrImageNeverPull, not ImagePullBackOff — that means the pull policy is Never but the image doesn't exist locally. Let me check what image tag was set."
- After describe deploy: "The image was changed to platform-drill-api:latest, but this is a kind cluster where images are loaded locally — latest was never loaded. The rollout is stuck with ProgressDeadlineExceeded. I'll roll back to the previous working revision."
- After fix: "Rollback complete, old ReplicaSet is back at 1/1, new one scaled to 0. Let me curl the endpoints to confirm the app is serving correctly."

## Key Learning

- `ErrImageNeverPull` vs `ImagePullBackOff`: different pull policy behavior, same bucket
- To find the working image tag: inspect the running pod or old ReplicaSet
- `rollout undo` reverts entire pod template; `set image` changes only the image — choose based on whether other spec changes are intentional
- Bucket B (pod signal) leads to Bucket C (deployment-level fix) — common cross-bucket pattern
