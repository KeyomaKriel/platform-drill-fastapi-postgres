# Scenario 08 — Deployment / Rollout

**Date:** 2026-04-07 ~08:36  
**Symptom presented:** "We pushed a new version of the API about 10 minutes ago, but users are still seeing the old version. The deploy went out — can you check why the new version isn't live?"

## What was broken

Deployment image changed from `platform-drill-api:local` to `platform-drill-api:v2.0.0` — a tag that doesn't exist on the node. With `imagePullPolicy: Never`, new RS pods went into `ErrImageNeverPull`. Rollout stalled; old pod kept serving.

**Failure domain:** Deployment / Rollout

## Fix

`kubectl set image deployment/platform-drill-api platform-drill-api=platform-drill-api:local` — restored the correct image tag. Rollout completed successfully.

**Fix succeeded:** Yes

## Evaluation

| Priority | Rating | Explanation |
|---|---|---|
| Orientation | Solid | Started with `get ns`, set namespace, then `get pods`. Got to the signal fast, though a broader `get all` or `get events` would have shown the stuck rollout more explicitly. |
| Intentional commands | Strong | Every command had a clear purpose. Used jsonpath on the old pod to find the correct image — exactly the right move. |
| Hypothesis-driven | Strong | Saw `ErrImageNeverPull`, identified bad tag, found correct tag from working pod, fixed it. Clean chain. |
| One fix at a time | Strong | Single `set image` command. No shotgunning. |
| End-to-end verification | Needs Work | Verified pods were Running with `get pods` but did not curl the app to confirm it was actually responding. |
| Communication | Needs Work | No narration in the session log. Key decision points (identifying the stuck rollout, committing to image pull as root cause, choosing set image over rollback) should be spoken aloud. |

## Notable commands

**Good:**
- `kubectl get pod <old-pod> -o jsonpath='{.spec.containers[0].image}'` — correct way to find the known-good image from the still-running pod
- `kubectl describe pod <failing-pod>` — went straight to the failing pod to read the error

**Missing / would improve:**
- `kubectl rollout status deploy/platform-drill-api` — would have confirmed the stuck rollout at the deployment level
- `kubectl get rs` — would have shown the two competing ReplicaSets
- `curl localhost/` after the fix — end-to-end verification

## Suggested narration

At `get pods`:
> "I see two API pods — one Running from 40h ago, one in ErrImageNeverPull that's new. This looks like a failed rollout — the new version can't start, so the old version is still serving."

At `describe pod`:
> "The image is platform-drill-api:v2.0.0 with pull policy Never. That tag doesn't exist locally. I need to find what the working tag was."

At checking old pod's image:
> "The working pod uses platform-drill-api:local. I'll set the deployment back to that."

After the fix:
> "Rollout completed. Let me curl the app to confirm it's actually responding end-to-end."
