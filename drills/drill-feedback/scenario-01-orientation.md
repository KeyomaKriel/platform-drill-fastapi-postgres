# Scenario 01 — Healthy Orientation

**Date:** 2026-04-08 13:38–14:00
**Task type:** Healthy orientation
**Result:** Partial

## Prompt given

> You've just joined a team and opened their application repository for the first time. The app is already deployed to a Kubernetes cluster you have access to (namespace: `drill`). Walk me through what this application does, how it's deployed, and how you'd verify it's working correctly.

## What was required

Demonstrate understanding of:
- App purpose: FastAPI with 3 endpoints (`/`, `/health`, `/items`), Postgres dependency
- Deploy path: Dockerfile builds image, K8s manifests deploy to `drill` namespace
- Key config: env vars from ConfigMap/Secret, init container, probes, RBAC, network policies, ingress
- End-to-end verification: pods, endpoints, curl all three routes

## Commands run

1. `ls` — directory listing
2. `tree` — full tree view
3. `kubectl get pods -n drill` — pod status
4. `kubectl get endpoints -n drill` — endpoint check
5. `curl -i localhost/` — root endpoint
6. `curl -i localhost/items` — items endpoint
7. `curl -i localhost/health` — health endpoint

## Evaluation

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Repo orientation | Needs Work | Saw structure via tree but never opened any files |
| Comprehension accuracy | Needs Work | No evidence of understanding app logic, deploy config, or dependencies |
| Systematic verification | Solid | Checked pods, endpoints, and all three curl routes with -i |
| Communication | Needs Work | No narration visible in session log |

## Notable good actions

- Used `curl -i` to include headers
- Checked endpoints, not just pod status
- Did verify all three routes

## Unnecessary/redundant actions

- None — the issue was insufficient depth, not wasted effort

## Suggested narration at key decision points

- After `tree`: "I can see this is a Python app with K8s manifests. Let me read the main application code first to understand what it does."
- After reading app code: "This is a FastAPI app with three endpoints. It depends on Postgres — let me check how that dependency is configured in the manifests."
- After reading manifests: "The app gets its DB config from a ConfigMap and Secret. There's an init container, liveness/readiness probes, and network policies. Let me verify this matches what's running."
- After curl tests: "All three endpoints return expected data. The app is healthy and the full request path — ingress to service to pod to database — is working."
