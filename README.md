# Platform Drill System

Practice environment for a 60-minute hands-on Platform Engineer technical interview. You run drills through Claude Code, which acts as interviewer, scenario generator, and evaluator.

The system creates fresh workspaces for each drill from a canonical template repo, deploys to a local Kubernetes cluster, and evaluates your debugging process, implementation quality, and communication.

---

## Folder structure

```
./
├── CLAUDE.md              # The operating manual — Claude Code follows this
├── source-repo/           # Canonical template repo (DO NOT edit during drills)
├── workspaces/            # Disposable drill workspaces (auto-created, auto-deleted)
├── drills/drill-feedback/ # Persistent feedback files from completed drills
├── playbook.md            # Triage reference — updated after debugging drills
├── playbook-old.md        # Previous playbook version
├── CLAUDE-old.md          # Previous operating manual version
├── prompts/               # Prompt drafts used to build the system
├── kind-config.yaml       # Kind cluster config (drill infrastructure)
├── cluster.yaml           # EKS cluster config (reference only)
├── cheat-sheet-general.md # General K8s cheat sheet
└── k8s-debug-flowchart.png
```

**What each key part does:**

| Path | Role | Who edits it |
|------|------|--------------|
| `CLAUDE.md` | Full operating manual. Claude Code reads this to know how to run drills. | You, intentionally, outside drills |
| `source-repo/` | The candidate-facing project template. Contains app code, Dockerfile, K8s manifests, README. | You, intentionally, outside drills. Never during a drill. |
| `workspaces/` | Where fresh drill workspaces are created. Each drill gets `workspaces/drill-workspace-01/`, `02/`, etc. | Claude Code creates them. You work inside them. They get deleted after evaluation. |
| `drills/drill-feedback/` | Structured feedback from each completed drill. Persists across drills. | Claude Code writes these after evaluation. |
| `playbook.md` | Your triage reference. Claude Code proposes updates after debugging drills. | Claude Code updates with your approval. |

---

## How the system works

### Phase 1 — Baseline bootstrap and verification

Sets up or verifies the local environment: kind cluster, Calico CNI, nginx Ingress, app image built and loaded, full stack deployed and healthy.

Run this first, or whenever you need to restore a clean baseline.

### Phase 2 — Drill workspace generation and task setup

Creates a fresh workspace under `workspaces/` by copying `source-repo/`. Chooses a task type and presents it as a realistic interview prompt.

Task types: repo orientation, single-fault debugging, small implementation/change, verification/trade-off.

### Phase 3 — Silent interviewer and evaluation

Claude Code stays silent while you work. When you're done, it reads your session log, verifies the outcome, gives structured feedback, writes a feedback file, and optionally proposes playbook updates.

### Phase 4 — Guided coaching

Instead of silent observation, Claude Code walks you through step by step — telling you what to notice, what to say out loud, and what to do next.

---

## Typical workflow

1. Open Claude Code in this folder.
2. Say **"run phase 1"** to bootstrap or verify the environment.
3. Wait for Phase 1 to complete and confirm healthy.
4. Say **"next scenario"** to start a drill.
5. Claude Code creates a workspace and presents a task.
6. In a **separate terminal**, cd into the workspace and start the session log:
   ```
   cd /path/to/workspaces/drill-workspace-01
   script -q -a ./session.log
   ```
7. Do the task in that terminal.
8. When done, go back to Claude Code and say **"evaluate my fix"** (or "evaluate", "done", etc.).
9. Claude Code reads the log, evaluates your work, writes feedback.
10. Say **"next scenario"** to start another drill.

---

## Phrases to use with Claude Code

| Say this | What happens |
|----------|-------------|
| `run phase 1` / `set up the environment` / `bootstrap` | Runs Phase 1 — creates or verifies the baseline environment |
| `next scenario` / `start drill` / `new drill` / `start phase 2` | Runs Phase 2 — creates a fresh workspace and presents a task |
| `evaluate my fix` / `evaluate` / `done` / `check my work` | Triggers Phase 3 evaluation — reads your session log and gives feedback |
| `just break something` / `test me` | Skips workspace creation, injects a fault directly, enters Phase 3 |
| `coach me on this one` / `help me through this` | Switches to Phase 4 — guided coaching instead of silent observation |
| `back to phase 3` / `test me again` | Returns from coaching to silent interviewer mode |
| `hint` / `I'm stuck` | Gets a small directional hint (Phase 3 only — won't give away the answer) |
| `how am I doing overall` | Gets a summary of patterns across all completed drills |

---

## Session logs, workspaces, and feedback

**Workspaces:**
- Created at `./workspaces/drill-workspace-<NN>/` for each drill
- Contains a copy of `source-repo/` contents with simulated git history
- Deleted after evaluation. Never reused.

**Session log:**
- Lives at `./workspaces/drill-workspace-<NN>/session.log`
- You start it with `script -q -a ./session.log` in the workspace
- Claude Code reads it during evaluation
- Deleted with the workspace

**Feedback files:**
- Saved to `./drills/drill-feedback/scenario-<NN>-<slug>.md`
- Persist across drills — these are your training record
- Include: what was broken, whether you fixed it, evaluation ratings, suggested narration

**What gets deleted after each drill:** The workspace directory and its session log.

**What persists:** Feedback files, playbook updates, the source repo, the cluster state (restored to healthy).

---

## Important operating rules

1. **`source-repo/` is read-only during drills.** All your drill work happens in a workspace. If you want to change the template (add a manifest, update app code), do it intentionally outside of a drill.

2. **Phase 1 is for baseline setup, not editing.** It builds from `source-repo/` and deploys. It does not modify `source-repo/`.

3. **Each drill starts from a fresh workspace.** Previous drill state does not leak into the next one.

4. **Faults are injected into the live cluster, not into workspace files.** You discover problems through runtime behaviour, not by diffing files.

5. **Claude Code does not help during Phase 3** unless you explicitly ask for a hint or switch to coaching mode.

---

## Reset and cleanup

**If a drill went wrong or the environment is messy:**

- Say **"run phase 1"** to Claude Code. It will verify and fix the cluster, clean up stale workspaces, and restore the healthy baseline.

**If the cluster is deeply broken:**

- Delete the kind cluster and re-bootstrap:
  ```
  kind delete cluster --name drill-cluster
  ```
  Then say **"run phase 1"** to rebuild from scratch.

**If you want to manually clean up workspaces:**

```
rm -rf ./workspaces/drill-workspace-*
```

**If you want to start a completely fresh drill session** (clean workspace state, fresh cluster):

1. `kind delete cluster --name drill-cluster`
2. `rm -rf ./workspaces/drill-workspace-*`
3. Open Claude Code and say "run phase 1"

---

## Common usage patterns

**I want a normal drill:**
Say "next scenario". Claude Code picks a task type, creates a workspace, and presents the task.

**I want debugging only:**
Say "just break something" or "next debugging scenario". Claude Code injects a fault and gives you a vague symptom.

**I want coaching instead of testing:**
Say "coach me on this one" before or during a drill. Claude Code guides you step by step instead of staying silent.

**I want to inspect the source repo first:**
Look at `source-repo/` directly. It's just a normal project folder. Don't edit it during drills.

**I want another scenario of the same type:**
Say "another debugging drill" or "give me another implementation task". Claude Code will honour specific requests.

**I want to see my progress:**
Say "how am I doing overall" or look at the files in `drills/drill-feedback/`.

---

## Quick start

```
# 1. Open Claude Code in this folder

# 2. Bootstrap the environment
> run phase 1

# 3. Wait for it to complete, then start a drill
> next scenario

# 4. In a separate terminal, cd into the workspace Claude Code tells you about
cd ./workspaces/drill-workspace-01
script -q -a ./session.log

# 5. Do the task

# 6. When done, go back to Claude Code
> evaluate my fix

# 7. Read the feedback, then
> next scenario
```
