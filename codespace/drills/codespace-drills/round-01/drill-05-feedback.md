# Drill 05 — Debugging Feedback

**Date:** 2026-04-11
**Task type:** Single-fault debugging
**Failure domain:** Application-level dependency / runtime failure (Tier 2)
**Injected fault:** fleet-db deployment scaled to 0 replicas — database gone, tracker init containers stuck
**Result:** Fixed successfully

## Evaluation

| Criteria | Rating | Notes |
|---|---|---|
| Entry mode | Solid | Started with get pods, noticed Init:0/1 and missing DB pod. No repo orientation. |
| Runtime flow | Needs improvement | Events showed "Scaled down fleet-db to 0" but user detoured through init container logs and configmaps before checking `get deploy`. |
| Signal reading | Solid | Identified all signals (no DB pod, stuck init, scale-down event, 0/0 deploy). Gap between seeing and acting. |
| Hypothesis-driven | Needs improvement | After seeing init container stuck on fleet-db-svc:5432, checked configmaps instead of checking whether the DB was running. |
| Intentional commands | Needs improvement | Configmap checks were off-track. Init container log dump produced ~350 identical lines. 4x get pods, 2x endpoints, 4x curl. |
| Smallest fix | Strong | `kubectl apply -f manifests/db-deployment.yaml` — repo as source of truth. |
| End-to-end verification | Strong | Watched recovery with `get pods -w`, checked endpoints, curled both routes through ingress. |
| Communication | N/A | No narration visible in log. |

## Notable good actions

- Checked events early — the scale-down was visible there
- Used `kubectl apply -f manifests/` to fix (repo as source of truth, consistent across drills)
- Watched the cascading recovery with `get pods -w` (DB ready → init completes → trackers ready)

## Areas for improvement

- **Follow the signal immediately.** After `describe pod` showed the init container stuck on fleet-db-svc, the next question is "Is the DB running?" — not "Is the config correct?" Check `get deploy` or `get pods` for the DB component.
- **Use `--tail=N` on logs.** `kubectl logs <pod> -c wait-for-db --tail=20` avoids hundreds of identical lines and gets the same signal.
- **Distinguish config problems from reachability problems.** "Can't reach fleet-db-svc:5432" means the target is down or the service is broken. Configmaps would only matter if the *hostname or port value* was wrong — and the init container output already shows the correct hostname.
- **Command discipline still needs tightening.** ~25 commands where ~7 would do.

## Pattern emerging across drills

- Fix approach is strong and consistent (repo manifests as source of truth)
- End-to-end verification is thorough
- Diagnosis-to-fix path still has unnecessary detours — commands that don't answer the current question
- No narration in any drill so far

## Suggested narration at key moments

- After `get pods`: "Both tracker pods are stuck in Init:0/1 — the init container can't complete. And I don't see a fleet-db pod at all. Let me check if the DB deployment is running."
- After `describe pod`: "The init container is waiting for fleet-db-svc:5432. Since there's no DB pod, that service has nothing behind it. Let me check the deployment."
- After `get deploy`: "fleet-db shows 0/0 — zero desired replicas. Someone or something scaled it down. I'll re-apply the manifest to restore it."
- After recovery: "DB is back, init containers completed, both tracker pods are 1/1 Running. Endpoints are populated and both API routes return expected data."
