# Scenario 01 — Healthy Orientation

**Date:** 2026-04-07 ~16:27
**Task type:** Healthy orientation
**Prompt:** "This is the app we've been running in Kubernetes. Can you walk me through what it does, how it's deployed, and how you'd verify everything is working?"

## What was required

Explore the repo, understand the application (purpose, endpoints, dependencies), identify the deploy path (Dockerfile → image → K8s manifests), and verify everything is working live. Narrate throughout.

**Succeeded:** No — orientation was incomplete.

## Evaluation

| Criteria | Rating | Explanation |
|---|---|---|
| Repo orientation | Needs Work | Ran `ls`, `tree`, and read the README. Did not read application code, Dockerfile, or K8s manifests. |
| Comprehension accuracy | Needs Work | Identified startup command from Dockerfile (via Claude Code) but didn't discover endpoints, DB dependency, or config flow. |
| Systematic verification | Needs Work | No kubectl commands. No curl tests. Live cluster never checked. |
| Communication | Needs Work | No narration in the session log. An interviewer would see file listings and a partial README read with no reasoning. |

## Notable commands

**Good:**
- `tree` — good structural overview early on

**Missing / would improve:**
- `cat app/main.py` — discover endpoints and app behaviour
- `cat app/db.py` — understand database connection
- `cat Dockerfile` — understand build/run path
- `cat k8s/app.yaml`, `cat k8s/app-config.yaml`, etc. — understand deployment config
- `kubectl get pods -n drill` — check live cluster state
- `kubectl get svc -n drill`, `kubectl get ingress -n drill` — understand routing
- `curl localhost/`, `curl localhost/health`, `curl localhost/items` — end-to-end verification

## Suggested narration

At `tree`:
> "OK, I see app code in app/, a Dockerfile, K8s manifests in k8s/, and a docker-compose for local Postgres. Let me read the application code first."

After reading main.py:
> "This is a FastAPI app with three endpoints: root returns app info, /health checks Postgres connectivity, /items returns rows from an items table. It depends on Postgres via environment variables."

After reading K8s manifests:
> "The app is deployed as a Deployment with an init container, behind an nginx Ingress. Postgres runs as a single-replica Deployment with a PVC. Config is split across ConfigMaps and Secrets."

After kubectl checks:
> "Both pods are Running and Ready. Services have endpoints. Let me verify end-to-end with curl."

After curl tests:
> "All three endpoints respond correctly. The app is healthy and serving through Ingress."
