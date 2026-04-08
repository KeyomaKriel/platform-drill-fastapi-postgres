# Scenario 02 — Config / Secret / Env Failure

**Date:** 2026-04-07 ~17:27
**Task type:** Single-fault debugging
**Failure domain:** #4 — Config / Secret / env failure
**Prompt:** "The API has been returning 503s for the last few minutes. It was working fine earlier today. Can you figure out what's going on and get it back up?"

## What was broken

`POSTGRES_HOST` in the `app-config` ConfigMap changed from `postgres` to `postgres-db`. App couldn't resolve the hostname, crashed on startup with `psycopg.OperationalError: failed to resolve host 'postgres-db'`.

## Fix

`kubectl edit configmap app-config` — changed `POSTGRES_HOST` back to `postgres`, then `kubectl rollout restart deployment/platform-drill-api`.

**Fix succeeded:** Yes

## Evaluation

| Criteria | Rating | Explanation |
|---|---|---|
| Entry mode | Solid | Went straight to cluster — appropriate for active 503s. |
| Runtime flow | Solid | pods → describe → logs → config investigation → fix. Logical. |
| Signal reading | Solid | Read logs, identified DNS failure, traced to ConfigMap. |
| Hypothesis-driven | Solid | After seeing `postgres-db` in error, investigated config sources. |
| Intentional commands | Needs Work | Many duplicate commands — get pods 8x, describe 4x each pod, logs 4x, wrong edit syntax repeated 4x. |
| Smallest justified fix | Strong | Edited one wrong value and restarted. Clean. |
| End-to-end verification | Needs Work | Watched pods come up but never ran curl to verify app responds through Ingress. |
| Communication | Needs Work | No narration in session log. |

## Notable commands

**Good:**
- `kubectl logs` — went to logs after describe, found the error quickly
- `kubectl get configmap app-config -o yaml` — checked live ConfigMap values
- `kubectl get secret -o json` + base64 decode — thorough config investigation
- `kubectl edit configmap app-config` — correct fix method (after syntax correction)

**Redundant / would improve:**
- `kubectl get pods` ran 8+ times with no new information between runs
- `kubectl describe pod` ran 4x per pod with same output
- `kubectl edit app-config` (wrong syntax) repeated 4x before correcting to `kubectl edit configmap app-config`
- No `curl localhost/`, `curl localhost/health`, `curl localhost/items` after fix

## Suggested narration

At `get pods`:
> "Two API pods in CrashLoopBackOff, Postgres is running fine. The app is crashing, not Postgres. Let me describe one of the crashing pods."

At logs:
> "The app is failing to resolve host 'postgres-db'. That's a DNS resolution error — the hostname is wrong. This comes from the POSTGRES_HOST env var, which is in the app-config ConfigMap."

At checking ConfigMap:
> "POSTGRES_HOST is set to 'postgres-db' in the live ConfigMap, but the Postgres service is called 'postgres'. The ConfigMap has a wrong hostname. I'll edit it and restart."

After fix:
> "ConfigMap updated, deployment restarted. Let me curl the endpoints to confirm it's working end-to-end."

## Coaching notes

This was a coached scenario. Key learning moments during coaching:
- Understanding DNS resolution errors ("failed to resolve host" = DNS failure)
- When rollout restart is needed (env vars from ConfigMap require pod restart)
- kubectl edit vs yaml edit + apply (either works; for live cluster faults, edit is fast)
- Trusting live cluster state as ground truth over file contents
