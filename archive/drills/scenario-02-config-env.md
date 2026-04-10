# Scenario 02 — Config / Secret / Env Failure (Debugging)

**Date:** 2026-04-08 14:12–14:37
**Task type:** Single-fault debugging
**Failure domain:** Config / Secret / env failure (Tier 1)
**Injected fault:** `POSTGRES_HOST` changed from `postgres` to `postgres-db` in `app-config` ConfigMap
**Result:** Fixed successfully

## Prompt given

> A teammate pinged you: "The API was working earlier today but now it's returning errors. Can you take a look?"

## What was required

Identify that the `app-config` ConfigMap had a wrong `POSTGRES_HOST` value (`postgres-db` instead of `postgres`), fix it, restart the app deployment, and verify end-to-end.

## Evaluation

| Criterion | Rating | Notes |
|-----------|--------|-------|
| Entry mode | Solid | Broad triage: pods → endpoints → deploy → logs |
| Runtime flow | Solid | Logical progression, some redundancy after finding key signal |
| Signal reading | Strong | Caught DNS error, cross-referenced with service name, noticed annotation showed original correct value |
| Hypothesis-driven | Solid | Investigated hostname source after DNS error; used annotation as evidence |
| Intentional commands | Solid | Mostly purposeful, some redundant exploration |
| Smallest justified fix | Strong | Edited one ConfigMap value + rollout restart |
| End-to-end verification | Needs Work | Checked pods/endpoints/logs but never curled endpoints |
| Communication | Needs Work | No narration visible |

## Notable good actions

- Spotted annotation showing original correct value for POSTGRES_HOST
- Used `kubectl edit` + `rollout restart` — correct fix path for envFrom ConfigMap
- Checked `--previous` logs for consistency

## Unnecessary/redundant actions

- JSON-inspected both services after logs already identified hostname issue
- Described both deployments when error was clearly config-related
- Described same pod twice
- `env | grep POSTGRES_DB` instead of POSTGRES_HOST (wrong variable)

## Suggested narration at key decision points

- After `kubectl get pods`: "I can see the API pod is in CrashLoopBackOff while postgres is healthy. Let me check the app logs to see why it's crashing."
- After seeing logs: "The error says it failed to resolve host 'postgres-db'. The postgres service is called 'postgres', not 'postgres-db'. So the app has the wrong hostname configured. Let me check where that comes from — it's likely in a ConfigMap or env var."
- After seeing ConfigMap: "The ConfigMap has POSTGRES_HOST set to 'postgres-db', but the annotation shows the original value was 'postgres'. Someone changed this. I'll fix it back and restart the deployment."
- After fixing: "Let me curl all three endpoints through the ingress to verify everything is working end-to-end."
