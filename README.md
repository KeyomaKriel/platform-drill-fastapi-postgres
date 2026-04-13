# Platform Drill System

Practice environment for a 60-minute hands-on Platform Engineer technical interview. You run drills through Claude Code (locally), which acts as interviewer, scenario generator, and evaluator. You debug inside a GitHub Codespace running k3d.

Three drill apps (Flask, Django, Go) give you variation in framework, project structure, and K8s manifest patterns. One app is deployed at a time. Claude Code generates realistic single-fault debugging scenarios, orientation tasks, implementation tasks, and trade-off questions.

---

## Folder structure

```
./
├── CLAUDE.md                               # Operating manual — Claude Code follows this
├── .devcontainer/                          # Codespace provisioning (k3d + nginx ingress)
├── codespace/
│   ├── drill-app/                          # Flask app (fleet tracking)
│   ├── drill-app-django/                   # Django app (incident management)
│   ├── drill-app-go/                       # Go app (warehouse inventory)
│   ├── drills/codespace-drills/            # Scenario files, answer keys, feedback
│   ├── guides/                             # Setup and operational guides
│   └── scripts/                            # Automation scripts
├── playbook.md                             # Troubleshooting handbook
├── docs/                                   # Reference docs (HTML troubleshooting guide, etc.)
└── prompts/                                # Prompt drafts
```

**What each key part does:**

| Path | Role |
|------|------|
| `CLAUDE.md` | Full operating manual. Claude Code reads this to know how to run drills, generate scenarios, and evaluate. |
| `.devcontainer/` | Provisions the Codespace with Docker, kubectl, helm, k3d, nginx Ingress. Runs automatically on Codespace creation. |
| `codespace/drill-app*` | Three self-contained apps, each with Dockerfile, K8s manifests, and `deploy.sh`. |
| `codespace/drills/codespace-drills/` | Scenario files (`drill-NN-scenario.md`), answer keys, and feedback from completed drills. |
| `codespace/guides/automated-multi-app-drill-setup.md` | Comprehensive setup and operational guide for the Codespace workflow. |
| `playbook.md` | Troubleshooting handbook — 11 failure domains, diagnostic commands, fix patterns. |

---

## Available apps

| App | Framework | Domain | Namespace | Health endpoint |
|-----|-----------|--------|-----------|-----------------|
| `drill-app` | Flask (Python) | Fleet tracking | `fleet-ops` | `/api/v1/status` |
| `drill-app-django` | Django + DRF (Python) | Incident management | `incident-mgmt` | `/api/v1/status` |
| `drill-app-go` | Go stdlib net/http | Warehouse inventory | `warehouse-sys` | `/readyz` |

Each app has different env var names, port numbers, init container patterns, probe configurations, and project structures — giving you unfamiliar repos to orient to each time.

---

## How the system works

### Phase 1 — Environment setup and verification

Verifies the Codespace is running, the k3d cluster and nginx Ingress are healthy, and the selected app is deployed.

### Phase 2 — Scenario generation

Generates a drill scenario for the selected app. For debugging drills, creates a base64-encoded fault injection command, a vague symptom prompt, and a detailed answer key with narration guidance.

### Phase 3 — Silent interviewer and evaluation

Claude Code stays silent while you work in the Codespace. When you're done, it reads your session log, verifies the outcome, gives structured feedback, and writes a feedback file.

### Phase 4 — Guided coaching

Instead of silent observation, Claude Code walks you through step by step — telling you what to notice, what to say out loud, and what to do next.

---

## Typical workflow

1. **Create a Codespace** (one-time):
   ```bash
   gh codespace create -R KeyomaKriel/platform-drill-fastapi-postgres -b mac-eks-drill -m basicLinux32gb --idle-timeout 30m --default-permissions
   ```

2. **Open the Codespace** in your browser:
   ```bash
   gh codespace code -c <codespace-name> --web
   ```

3. **Deploy an app** from the Codespace terminal:
   ```bash
   cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
   bash deploy.sh
   ```

4. **Open Claude Code locally** and say:
   > Generate the next drill scenario for drill-app-django.

5. Claude Code creates the scenario files silently.

6. **In the Codespace**, start the session log, inject the fault, and start debugging:
   ```bash
   cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
   script -q -a ./session.log
   # Paste the base64 break command from the scenario file
   # Debug the symptom
   ```

7. When done, go back to Claude Code:
   > Evaluate my fix.

8. Claude Code reads the log, evaluates, writes feedback. Then:
   > Generate the next drill scenario.

---

## Phrases to use with Claude Code

| Say this | What happens |
|----------|-------------|
| `run phase 1` / `check the codespace` | Verifies Codespace, cluster, and app health |
| `next scenario` / `generate the next drill for drill-app-go` | Generates a scenario for the specified (or current) app |
| `evaluate my fix` / `done` / `check my work` | Reads session log, evaluates, writes feedback |
| `just break something` | Injects a fault directly without creating scenario files |
| `coach me on this one` | Switches to guided coaching mode |
| `back to phase 3` / `test me again` | Returns to silent interviewer mode |
| `hint` / `I'm stuck` | Gets a small directional hint (won't give away the answer) |
| `how am I doing overall` | Summary of patterns across all completed drills |

---

## Switching between apps

Only one app can be deployed at a time (they all use the same Ingress path `/`).

In the Codespace:

```bash
# Tear down current app
kubectl delete namespace incident-mgmt

# Deploy a different one
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go
bash deploy.sh
```

---

## Session logs and feedback

**Session log:** Captured in the selected app directory (`session.log`) inside the Codespace. Start with `script -q -a ./session.log`. Claude Code reads it during evaluation.

**Feedback files:** Saved to `codespace/drills/codespace-drills/drill-<NN>-feedback.md`. Persist across drills — these are your training record.

**What persists:** Feedback files, scenario files, answer keys, playbook updates.

---

## Reset and cleanup

**Restore a healthy app after a drill:**
```bash
# In the Codespace — re-apply manifests
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
kubectl apply -f manifests/
kubectl rollout status deployment/incident-api -n incident-mgmt
```

**If the cluster is broken:**
```bash
# In the Codespace — recreate from scratch
bash /workspaces/platform-drill-fastapi-postgres/.devcontainer/setup-cluster.sh
```

**If the Codespace is gone:**
```bash
# From your Mac
gh codespace create -R KeyomaKriel/platform-drill-fastapi-postgres -b mac-eks-drill -m basicLinux32gb --idle-timeout 30m --default-permissions
```

---

## Quick start

```bash
# 1. Create and open Codespace (one-time)
gh codespace create -R KeyomaKriel/platform-drill-fastapi-postgres -b mac-eks-drill -m basicLinux32gb --idle-timeout 30m --default-permissions
gh codespace code -c <name> --web

# 2. In the Codespace terminal, deploy an app
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django
bash deploy.sh

# 3. Locally in Claude Code
> Generate the next drill scenario for drill-app-django.

# 4. In the Codespace, start session log and inject the fault
script -q -a ./session.log
# Paste the break command from the scenario file, then debug

# 5. When done, back in Claude Code
> Evaluate my fix.

# 6. Next drill
> Generate the next drill scenario.
```
