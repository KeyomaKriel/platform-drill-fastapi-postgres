# The Distinction Between Pod Symptom and Root-Cause Domain

This is the single most important conceptual tool for Kubernetes debugging. Getting it wrong means you fix the wrong thing or chase the wrong trail.

## The distinction

**A symptom** is what you observe. It's the surface-level signal that tells you something is wrong.

**A root-cause domain** is where the fix actually lives. It's the category of problem that, once resolved, makes the symptom go away.

They are not the same thing, and the mapping between them is one-to-many.

## Why this matters

If you treat the symptom as the root cause, you'll try to "fix" the symptom directly — which often means fixing the wrong thing.

Example: you see `CrashLoopBackOff`. If you treat that as the root cause, you might try to adjust restart policies or increase failure thresholds. But `CrashLoopBackOff` just means "the container keeps crashing." The question is *why* it's crashing — and the answer could be in at least six different root-cause domains.

## CrashLoopBackOff — the clearest example

CrashLoopBackOff is a **symptom hub**. It's the most common pod symptom, and it routes to the widest range of root causes:

| What the logs show | Root-cause domain |
|---|---|
| `configmap "X" not found` | Config / Secret / Env |
| `POSTGRES_HOST` is set to a wrong value | Config / Secret / Env |
| `Name or service not known` | DNS / Namespace (or Config if the hostname value is wrong) |
| `connection refused` to a dependency | App-Level Dependency (or Config if the host/port is wrong) |
| OOMKilled / exit 137 | Resource / Scheduling / Storage |
| `ModuleNotFoundError` or stack trace | Startup / Crash (app code or image) |
| App starts fine then gets killed | Probe Failure (liveness probe) |

The pod status is the same in all cases: `CrashLoopBackOff`. But the fix is completely different depending on which domain the root cause lives in.

## Other symptom-to-root-cause mappings

| Symptom | Possible root causes |
|---|---|
| 503 from Ingress | Probe Failure (readiness → empty endpoints), Service Routing (selector mismatch), App-Level (app returning errors) |
| Empty endpoints | Service Routing (selector mismatch), Probe Failure (pods not Ready) |
| Pod `Pending` | Resource/Scheduling (insufficient CPU/memory), Storage (PVC won't bind), Node issues (taints, affinity) |
| `connection refused` in logs | App-Level (dependency down), Config (wrong host/port value), DNS (hostname doesn't resolve) |

## The routing rule

1. **Start from the symptom.** It tells you where to look first.
2. **Gather evidence.** Use `describe`, `logs`, `get endpoints`, etc.
3. **Let the evidence tell you the root-cause domain.** Don't decide the domain before you have evidence.
4. **Fix the root cause, not the symptom.**

The troubleshooting sequence in the playbook is designed around this principle: pod status tells you the symptom, then commands like `describe` and `logs` give you evidence, then the evidence routes you to the correct root-cause domain.

## The practical test

Before you apply a fix, ask: "Am I fixing the root cause, or am I fixing the symptom?" If your fix is "increase the restart backoff" for a CrashLoopBackOff, you're fixing the symptom. If your fix is "correct the database hostname in the ConfigMap," you're fixing the root cause.
