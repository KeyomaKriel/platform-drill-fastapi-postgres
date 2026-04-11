# Drill 06 — Debugging Feedback

**Date:** 2026-04-11
**Task type:** Single-fault debugging
**Failure domain:** Image pull / container creation failure (Tier 1)
**Injected fault:** fleet-tracker image changed from `fleet-tracker:local` to `fleet-tracker:v2.1.0` (doesn't exist, imagePullPolicy: Never)
**Result:** Fixed successfully

## Evaluation

| Criteria | Rating | Notes |
|---|---|---|
| Entry mode | Solid | get pods first, spotted ErrImageNeverPull immediately. |
| Runtime flow | Strong | Tightest path yet: pods → describe → deploy → apply manifest → verify. One minor redundancy. |
| Signal reading | Strong | Read ErrImageNeverPull status, wrong image tag, and "not present with pull policy Never" without detour. |
| Hypothesis-driven | Solid | Clear diagnostic chain. Would be stronger with narration. |
| Intentional commands | Solid | No configmap/log/service detours. Only extra was full deploy YAML after diagnosis was already clear. |
| Smallest fix | Strong | `kubectl apply -f manifests/tracker-deployment.yaml`. |
| End-to-end verification | Strong | Pods + endpoints + curled both API routes. |
| Communication | N/A | No narration visible. |

## Notable good actions

- No detours into configmaps, logs, or services — stayed on the image pull issue
- Recognised ErrImageNeverPull immediately and went straight to describe
- Consistent use of repo manifests to fix
- Noticed `last-applied-configuration` still showed `fleet-tracker:local`, confirming the live spec had diverged

## Areas for improvement

- **Skip full deploy YAML when describe pod already gave the answer.** After seeing the wrong image tag in describe, go straight to the manifest to confirm the correct tag, then apply. The deployment YAML dump added ~120 lines for a fact already established.
- **Narrate.** Still the biggest gap. Practice saying one sentence at each step.

## Progress trend

| Drill | Domain | Diagnostic commands | Detours |
|---|---|---|---|
| 03 | Probe | ~12 | Full deploy YAML |
| 04 | Selector | ~14 | Repeated commands, deploy YAML x2 |
| 05 | DB down | ~18 | Configmaps, 350-line log dump |
| 06 | Image | ~4 | One deploy YAML dump |

Clear improvement in command discipline and signal-following. Fix approach (repo manifests) is fully consistent. Narration remains the gap.
