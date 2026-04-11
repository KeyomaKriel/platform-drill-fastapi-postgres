# Drill 04 — Debugging Feedback

**Date:** 2026-04-10
**Task type:** Single-fault debugging
**Failure domain:** Service routing / endpoint failure (Tier 1)
**Injected fault:** Service `tracker-svc` selector changed from `component: api` to `component: web`
**Result:** Fixed successfully

## Evaluation

| Criteria | Rating | Notes |
|---|---|---|
| Entry mode | Solid | Started with pods + endpoints. No repo orientation, but reasonable for the symptom. |
| Runtime flow | Solid | Core sequence was right (endpoints → describe svc → pod labels → mismatch). Significant redundancy: 4x curl, 3x endpoints, 2x full deploy YAML. |
| Signal reading | Strong | Spotted empty endpoints, went to describe svc, found selector mismatch, confirmed with pod labels. Textbook. |
| Hypothesis-driven | Solid | Logical chain visible in command sequence. No explicit hypothesis statements. |
| Intentional commands | Needs improvement | Key commands (describe svc, get pods --show-labels) were exactly right. But ~20 commands where ~10 would do. Full deploy YAML was a detour. |
| Smallest fix | Strong | `kubectl apply -f manifests/tracker-service.yaml` — used repo as source of truth. Improvement over drill 03's manual patch. |
| End-to-end verification | Strong | Verified service YAML post-apply, then curled both endpoints. |
| Communication | N/A | No narration visible in log. |

## Notable good actions

- Used `kubectl apply -f manifests/tracker-service.yaml` to restore from repo — source-of-truth approach
- Correct diagnostic chain: empty endpoints → describe svc → pod labels → selector mismatch
- Verified the service YAML after applying to confirm the selector was corrected

## Areas for improvement

- **Command discipline.** ~20 commands where ~10 would do. Before each command, ask: "What specific question does this answer?" Redundant curls, repeated endpoints/svc checks, and full deploy YAML dumps didn't advance the diagnosis.
- **Skip the deployment YAML.** Once you see empty endpoints on a service, the problem is between the service and the pods (selector/labels). The deployment spec is irrelevant unless you suspect the pod template labels are wrong — and even then, `get pods --show-labels` answers that faster.
- **Narrate.** State what you see and what you're going to check next: "Endpoints are empty for tracker-svc. I'm going to check what the service is selecting and compare it to the pod labels."

## Improvement from previous drills

Used the repo manifest to fix instead of a manual kubectl patch. This shows the repo-as-source-of-truth habit has stuck from drill 03 feedback.

## Suggested narration at key moments

- After `get endpoints`: "tracker-svc has no endpoints, but the pods are Running and Ready. That tells me the service selector isn't matching the pod labels."
- After `describe svc`: "The selector is `component=web`. Let me check what labels the pods actually have."
- After `get pods --show-labels`: "Pods have `component=api`, service selects `component=web` — that's the mismatch. I'll re-apply the service manifest from the repo."
- After verification: "Endpoints are populated now and both API endpoints return expected data. Fixed."
