# Platform Drill — K8s Interview Prep

Kubernetes troubleshooting practice environment for a 60-minute hands-on Platform Engineer interview. Uses Claude Code as both infrastructure setup tool and interview simulator.

## Prerequisites

- Intel Mac with Docker Desktop running
- Claude Code installed and authenticated
- Git

## Quick Start

### 1. Open Claude Code in the repo

```bash
cd ~/code/platform-drill-fastapi-postgres
claude
```

Claude Code will automatically read `CLAUDE.md` and understand the full setup.

### 2. Set up the environment (Phase 1)

In Claude Code, type:

```
run phase 1
```

This will take a few minutes. Claude Code will:
- Check and install any missing tools (kind, kubectl, helm)
- Create a kind cluster with Calico CNI and nginx Ingress
- Build your app image and load it into the cluster
- Deploy the full production-grade stack (Postgres + app + Ingress + NetworkPolicies + RBAC)
- Verify everything is healthy and show you the final state

Don't proceed until you see: **"Phase 1 complete. Environment is healthy and ready for Phase 2."**

### 3. Open a second terminal for debugging

Open a new terminal tab/window. This is where you'll run all your `kubectl` commands during drills.

Start session logging so Claude Code can review your work:

```bash
script -a ~/code/platform-drill-fastapi-postgres/drill-session.log
```

Keep this terminal open for the rest of your practice session.

### 4. Start a drill (Phase 2)

Back in Claude Code, type:

```
next scenario
```

Claude Code will:
1. Silently break something in the cluster
2. Give you a vague symptom (like a real interviewer would)
3. Wait for you to debug

### 5. Debug in your second terminal

Switch to your debug terminal and start triaging. Practice the methodology:

**Orient first:**
```bash
kubectl get all -n drill
kubectl get events -n drill --sort-by=.metadata.creationTimestamp
```

**Identify the bucket, then dig in with targeted commands.**

**Practice narrating out loud** as you work — say what you see, what you think the problem is, and why you're running each command. This is what the interview actually tests.

### 6. Get evaluated

When you've fixed the issue (or you're stuck), go back to Claude Code and type:

```
evaluate my fix
```

Claude Code will:
- Read your session log to see exactly what you did
- Check if the cluster is actually healthy
- Tell you whether you fixed the root cause
- Give feedback on your triage process, command choices, and narration
- Reveal what the break was
- Restore the cluster to healthy
- Clear the session log

### 7. Repeat

```
next scenario
```

Claude Code tracks which failure domains have been covered. To see progress:

```
which domains have we covered?
```

To get a summary of your performance across all scenarios:

```
how am I doing overall?
```

## If You Get Stuck

### Ask for a hint

In Claude Code, type:

```
give me a hint
```

You'll get a small directional nudge, not the answer. Ask again for a slightly bigger hint.

### Switch to coaching mode (Phase 3)

If you're struggling with a particular type of failure and want active guidance:

```
coach me on this one
```

Claude Code switches from silent interviewer to active coach. It will tell you what to notice in your output, what to say out loud, and what command to run next.

You can either paste kubectl output into Claude Code, or just say:

```
check the log
```

To go back to independent practice:

```
back to phase 2
```

## Useful Commands

| What | Where to type | Command |
|---|---|---|
| Set up environment | Claude Code | `run phase 1` |
| Start/next drill | Claude Code | `next scenario` |
| Get evaluated | Claude Code | `evaluate my fix` |
| Get a hint | Claude Code | `give me a hint` |
| Switch to coaching | Claude Code | `coach me on this one` |
| Go back to drills | Claude Code | `back to phase 2` |
| Check progress | Claude Code | `which domains have we covered?` |
| Overall feedback | Claude Code | `how am I doing overall?` |
| Start session log | Debug terminal | `script -a ~/code/platform-drill-fastapi-postgres/drill-session.log` |
| Clear session log | Debug terminal | `> ~/code/platform-drill-fastapi-postgres/drill-session.log` |

## Resetting

If things get into a bad state:

```
run phase 1
```

Phase 1 is idempotent — it will fix whatever's broken without recreating everything from scratch.

To fully nuke and start over:

```bash
kind delete cluster --name drill-cluster
```

Then `run phase 1` again in Claude Code.

## The 12 Failure Domains

These are the types of breaks Claude Code will introduce. You won't know which one you're getting — that's the point.

1. Networking / Service routing
2. Configuration injection
3. Image / container startup
4. Health probes
5. Resource constraints
6. Application-level failures
7. Namespace and RBAC
8. Deployment / rollout
9. Storage
10. Init containers / job dependencies
11. Network policies
12. Ingress / external access
