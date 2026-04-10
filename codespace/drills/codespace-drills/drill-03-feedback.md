# Drill 03 — Debugging Feedback

**Date:** 2026-04-10
**Task type:** Single-fault debugging
**Failure domain:** Probe failure (Tier 1)
**Injected fault:** Readiness probe port changed from 7600 to 8080
**Result:** Fixed successfully

## Evaluation

| Criteria | Rating | Notes |
|---|---|---|
| Entry mode | Solid | Went to cluster directly, spotted 0/1 pod quickly. No repo orientation — didn't check manifests for intended config. |
| Runtime flow | Strong | Logical: pods → describe unhealthy → logs → describe healthy for comparison → configmap → deployment YAML → fix. |
| Signal reading | Strong | Read the readiness/liveness port mismatch and "connection refused on 8080" event from describe output. |
| Hypothesis-driven | Solid | Gathered evidence before fixing. Would be stronger with explicit hypothesis statements. |
| Intentional commands | Solid | Each command purposeful. Configmap check slightly tangential but reasonable. |
| Smallest fix | Strong | Clean `kubectl patch` to correct just the readiness probe port. |
| End-to-end verification | Strong | Pods Running/Ready, curled both /api/v1/status and /api/v1/vehicles. |
| Communication | N/A | No narration visible in log. Must narrate in interview. |

## Notable good actions

- Compared unhealthy pod describe with healthy pod describe — effective way to spot the difference
- Checked the full deployment YAML and noticed `last-applied-configuration` still showed port 7600, confirming live spec had been changed outside of `kubectl apply`
- Minimal fix, no over-correction

## Areas for improvement

- **Orient to repo first.** Reading `manifests/tracker-deployment.yaml` before touching the cluster gives you the intended state as a baseline. If all pods were broken (no healthy old ones to compare), the repo would be your only reference.
- **Narrate.** In the interview, say what you see and what you're thinking: "Readiness probe is on 8080, liveness is on 7600, app logs show it's listening on 7600 — so the readiness probe port looks wrong."
- **State the hypothesis before fixing.** "My theory is the readiness probe is targeting the wrong port. Let me patch it back to 7600 and see if the pods become ready."

## Suggested narration at key moments

- After `describe pod`: "I can see the readiness probe is hitting port 8080 but the liveness probe is on 7600. The events show connection refused on 8080. The app logs confirm it's listening on 7600. So the readiness probe port looks wrong."
- Before patching: "I'm going to patch the readiness probe port back to 7600 to match what the app is actually listening on."
- After verification: "Pods are all Running and Ready, and both endpoints return expected data. The fix is confirmed."
