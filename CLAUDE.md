# Platform Drill — Operating Manual

## Purpose

This repo is a practice environment for a 60-minute hands-on Platform Engineer technical interview. The interview format is a **repo-based practical task in a prepared environment** (Codespaces), with engineers observing and lightly guiding.

The candidate is allowed to use a browser and AI. The interview tests **systematic triage, repo orientation, debugging process, implementation quality, and communication** — not recall.

Kubernetes break/fix is one layer of this practice, not the whole frame. A strong candidate orients to the repo first, understands the intended run/deploy path, then operates on the cluster with that context.

---

## Environment

- **Runtime:** GitHub Codespace with Docker-in-Docker, kubectl, helm, and k3d
- **Cluster:** k3d (`drill-cluster`) inside the Codespace, with nginx Ingress controller
- **Devcontainer:** `.devcontainer/` in this repo auto-provisions the cluster and Ingress on Codespace creation
- **Local machine:** Apple Silicon Mac running Claude Code. Claude Code generates scenarios and evaluates — the user debugs inside the Codespace.
- **One app deployed at a time.** All apps share the same Ingress path (`/`), so deploying a new app requires deleting the previous namespace first.

### Drill apps

Three apps are available under `codespace/`. Each is a self-contained project with its own Dockerfile, K8s manifests, and `deploy.sh`.

| App directory | Framework | Domain | Namespace | Port | Health endpoint | DB env vars | Image name |
|---|---|---|---|---|---|---|---|
| `codespace/drill-app` | Flask (Python) | Fleet tracking | `fleet-ops` | 7600 | `/api/v1/status` | `PG*` | `fleet-tracker:local` |
| `codespace/drill-app-django` | Django + DRF (Python) | Incident management | `incident-mgmt` | 8200 | `/api/v1/status` | `POSTGRES_*` | `incident-api:local` |
| `codespace/drill-app-go` | Go stdlib net/http | Warehouse inventory | `warehouse-sys` | 9090 | `/readyz` (readiness), `/healthz` (liveness) | `DB_*` | `inventory-api:local` |

**Key structural differences between apps:**

| Aspect | Flask | Django | Go |
|---|---|---|---|
| Entry point | `src/app.py` | `manage.py` / `config/wsgi.py` | `main.go` |
| Server | gunicorn | gunicorn | built-in http.Server |
| DB seeding | App seeds at startup | Init container runs `manage.py migrate` + `loaddata` | App seeds at startup |
| Init containers | 1 (wait-for-db) | 2 (wait-for-db + run-migrations) | 1 (wait-for-db) |
| Dockerfile | Single stage | Single stage | Multi-stage |
| Probes | Both hit `/api/v1/status` (checks DB) | Both hit `/api/v1/status` (checks DB) | Liveness `/healthz` (no DB check), Readiness `/readyz` (checks DB) |

When designing scenarios, reading manifests, or evaluating fixes, always use the **selected app's actual values** — do not assume one app's patterns apply to another.

### Filesystem layout

```
./                                          # Repo root (Claude Code runs here)
├── CLAUDE.md                               # This operating manual
├── .devcontainer/                          # Codespace provisioning (k3d + nginx)
├── codespace/
│   ├── drill-app/                          # Flask app
│   ├── drill-app-django/                   # Django app
│   ├── drill-app-go/                       # Go app
│   ├── drills/
│   │   └── codespace-drills/
│   │       ├── round-01/                   # Completed round (not scanned)
│   │       ├── round-02/                   # Current active round
│   │       └── round-NN/                   # Latest round-NN/ is always the active round
│   ├── guides/
│   │   └── automated-multi-app-drill-setup.md  # Operational reference
│   └── scripts/
├── playbook.md                             # Troubleshooting handbook
├── docs/                                   # Reference docs (HTML guides, etc.)
└── prompts/                                # Prompt drafts and notes
```

### Accessing the Codespace

**Browser (recommended for drills):** `gh codespace code -c <name> --web`

**SSH (for scripting/quick commands):** `gh codespace ssh -c <name>`

The repo is cloned inside the Codespace at `/workspaces/platform-drill-fastapi-postgres/`. All app directories are already there — no file copying needed.

---

## Key Definitions

- **Selected app**: The app directory the user has chosen for the current drill session (e.g. `codespace/drill-app-django`). All scenario generation, fault injection, and evaluation are scoped to this app.
- **Healthy baseline**: The selected app is deployed, all pods Running/Ready, endpoints populated, and the app's health and data endpoints return expected responses through Ingress (`curl localhost/...`).
- **Session log**: Terminal capture file (`session.log`) inside the selected app directory in the Codespace. The user starts it with `script -q -a ./session.log`.
- **Scenario files**: Drill scenario and answer files inside the active round folder. Named `drill-<NN>-scenario.md` and `drill-<NN>-scenario-answer.md`. Numbering resets each round.
- **Feedback files**: Evaluation results inside the active round folder. Named `drill-<NN>-feedback.md`.
- **Rounds**: Each round lives in `codespace/drills/codespace-drills/round-NN/`. The **latest (highest-numbered) `round-NN/`** subfolder is always the active round. All scenario generation, domain coverage scanning, and feedback writing happen inside this folder. Earlier rounds are not scanned — this allows Tier 1 domains to be practised again. The user creates new round folders when they want a fresh start.

---

## Phase 1 — Environment Setup and Verification

**Trigger:** The user says "run phase 1", "set up the environment", "check the codespace", or similar.

**Goal:** Verify that the Codespace is running, the k3d cluster and nginx Ingress controller are healthy, and a selected app can be deployed.

Phase 1 is idempotent — safe to run repeatedly.

### Steps

1. **Verify Codespace is running.**
   ```bash
   gh codespace list -R KeyomaKriel/platform-drill-fastapi-postgres --json name,state
   ```
   If no Codespace exists or it's Shutdown, guide the user to create or start one.

2. **Verify cluster health** (run inside Codespace via SSH).
   ```bash
   gh codespace ssh -c <name> -- 'k3d cluster list && kubectl get nodes && kubectl get pods -n ingress-nginx'
   ```
   - k3d cluster `drill-cluster` must exist and be running.
   - Node must be Ready.
   - Ingress controller must be Running/Ready.
   - If anything is missing, run `.devcontainer/setup-cluster.sh` inside the Codespace.

3. **Deploy the selected app** (if not already deployed and healthy).
   ```bash
   gh codespace ssh -c <name> -- 'cd /workspaces/platform-drill-fastapi-postgres/codespace/<app-dir> && bash deploy.sh'
   ```
   The `deploy.sh` script builds the image, loads it into k3d, applies manifests, waits for rollouts, and verifies health end-to-end.

4. **Verify healthy baseline** for the selected app.
   Run the app-specific health and data endpoint checks through Ingress. The endpoints differ by app — use the app table above.

5. **Report the final state.**
   Confirm: "Phase 1 complete. [App name] is deployed and healthy in [namespace]."

### Important rules for Phase 1
- Be idempotent. Do not fail if things already exist.
- If anything fails, diagnose and fix before reporting success.
- Do not proceed to Phase 2 automatically. Wait for the user to trigger it.
- Only one app can be deployed at a time. If a different app's namespace exists, delete it first.

---

## Phase 2 — Scenario Generation

**Trigger:** The user says "next scenario", "new drill", "generate the next drill", or provides a short prompt like:
- "Generate the next drill scenario for `codespace/drill-app-django`."
- "Generate the next Go debugging drill."
- "Next drill."

If no app is specified, use whichever app is currently deployed. If none is deployed, ask.

**Goal:** Generate a scenario file for the user to work on and prepare the environment.

### Pre-flight checks

1. **Verify healthy baseline** for the selected app. If unhealthy, restore before proceeding.
2. **Find the active round folder.** List `codespace/drills/codespace-drills/round-*/` and use the highest-numbered one. If none exist, ask the user.
3. **Determine the next scenario number.** Scan `drill-*-scenario.md` inside the active round folder and increment from the highest number found. If no scenarios exist, start at 01.
4. **Check failure domain coverage.** Read previous scenario answer files inside the active round folder to determine which failure domains have been used.

### Task types

Each drill uses one of these task types:

#### 1. Healthy orientation
- **No fault injected.** Cluster is healthy.
- Prompt: "Walk me through what this application does, how it's deployed, and how you'd verify it's working."
- Tests: repo reading, manifest comprehension, systematic verification, communication.

#### 2. Single-fault debugging
- **One fault injected** into the live cluster via base64-encoded kubectl command.
- User gets a vague symptom. Must discover the problem through runtime behaviour.
- Tests: triage process, signal reading, hypothesis-driven debugging, fix quality.

#### 3. Small implementation/change
- **No fault injected.** Cluster is healthy.
- User makes a small, realistic manifest/config-level change and deploys it.
- **Constraints:** Completable in 10–15 minutes. Prefer manifest/config-only tasks. Do not invent tasks requiring app code changes unless the user explicitly requests it.

#### 4. Verification/trade-off
- **No fault injected.** Cluster is healthy.
- User evaluates something about the current setup. Must inspect before answering.
- Push for specifics grounded in observation, not generic best practices.

### Task selection rules

1. **First drill on a new app:** Always healthy orientation.
2. **Subsequent drills:**
   a. Don't repeat the same task type consecutively (unless requested).
   b. ~50–60% debugging tasks.
   c. For debugging, draw from Tier 1 domains first. Cover all Tier 1 before moving to Tier 2. Use Tier 3 only if Tiers 1–2 are well covered or explicitly requested.
   d. Interleave implementation and verification between debugging drills.
   e. After three debugging tasks in a row, insert a non-debugging task.
   f. Honour explicit user requests.
3. **Track and report** task types, failure domains, and tiers when asked.

### Standard scenario generation (debugging tasks)

This is the default behaviour when the user asks for the next drill scenario.

**File creation:**

1. Create `codespace/drills/codespace-drills/round-NN/drill-<NN>-scenario.md` containing:
   - Setup instructions (which app, verify healthy first)
   - The base64-encoded break command to paste in the Codespace
   - Session log start command
   - A vague, realistic symptom prompt suitable for a technical interview
   - 15-minute timer

2. Create `codespace/drills/codespace-drills/round-NN/drill-<NN>-scenario-answer.md` containing:
   - App name, failure domain, tier
   - Exactly what was injected and why it causes the symptom
   - What will happen after injection (pod states, error messages, curl behaviour)
   - Key signals the candidate should find (table: signal, where, what it means)
   - Ideal diagnostic path (~8–12 commands)
   - **Narration guide** — what to say out loud at each stage of diagnosis
   - What to watch for as assessor (good signs, amber flags, red flags)
   - Evaluation criteria table (8 dimensions, Needs Work / Solid / Strong)
   - Graduated hints (3 levels: directional, more specific, pointed)

**Fault design rules:**

- Read the selected app's actual manifests to design the break. Do not assume values from other apps.
- Use `kubectl` commands (patch, set image, set env, delete, scale) to break something in the running cluster.
- Only break ONE thing per scenario.
- The fault must be diagnosable and fixable in ~10–20 minutes using repo inspection and standard kubectl commands.
- Base64-encode the break command so the user cannot read it in the approval prompt.
- Include `&& clear` at the end of the encoded command.
- After encoding, verify the decoded command is correct.

**Failure domain selection:**

- Check which domains have been used in previous drills (read answer files).
- Pick a Tier 1 domain that hasn't been used, unless all Tier 1 are covered, then Tier 2. Once Tier 2 is also covered, tell the user so the user can decide how to proceed.
- If the user specifies a domain or tier, honour that.

**Visibility rules:**

- **Do NOT reveal, hint at, or discuss the fault type, failure domain, or what the break does in the visible response.** Just create the files silently.
- On success, respond with a minimal confirmation such as ‘Done.’ Do not include any fault details.

### Failure domain likelihood tiers

**Tier 1 — High likelihood (prioritise):**
- Config / Secret / env failure (wrong value, missing ref, typo)
- Probe failure (wrong path, wrong port, timing)
- Service routing / port / endpoint failure (selector mismatch, port mismatch)
- Image pull / container creation failure (wrong tag, missing image)

**Tier 2 — Moderate likelihood:**
- Ingress / external routing failure
- Application-level dependency / runtime failure
- Startup / crash failure (bad entrypoint, missing config)

**Tier 3 — Low likelihood (only if requested or Tiers 1–2 well covered):**
- NetworkPolicy / traffic restriction failure
- RBAC / service account / permission failure
- Resource / scheduling / storage failure
- DNS / service discovery / namespace failure

### Preferred subcases for Tier 1/2 domains

These are the most interview-realistic fault patterns:

| Domain | Preferred subcases |
|---|---|
| Config / Secret / env | Wrong env var value, wrong ConfigMap/Secret reference name, missing Secret key, typo in hostname |
| Probe failure | Wrong probe HTTP path, wrong probe port, both probes targeting nonexistent path |
| Service routing | Service selector label mismatch (empty endpoints), wrong targetPort (but see caveat below) |
| Image pull | Wrong image tag, image not loaded into k3d, imagePullPolicy mismatch |
| Ingress | Wrong ingressClassName, wrong backend service name, wrong backend port |
| App dependency | Wrong DB hostname in ConfigMap, wrong credentials, dependency scaled to zero |
| Startup / crash | Bad command/args override, wrong binary name, missing required env var |

**Service targetPort caveat:** A targetPort-only change may not manifest when testing through nginx Ingress (the Ingress controller can bypass kube-proxy). Prefer selector mismatches for Service routing faults, or combine targetPort changes with an explicit port-forward verification step in the answer key.

### Explicitly avoid by default

- Multi-fault scenarios
- Obscure Kubernetes edge cases
- Deep cluster internals (CNI, node-level, control-plane, etcd)
- Storage/scheduler/taint-heavy issues
- Cluster-admin style troubleshooting
- Faults that require more than ~20 minutes to diagnose
- Faults that require tools beyond kubectl and curl

---

## Phase 3 — Interview Simulation and Evaluation

**Trigger:** Entered from Phase 2 after a scenario is presented, or directly if the user says "just break something" or "test me", or when the user says "evaluate my fix."

**Goal:** Act as a technical interviewer. Observe silently during the drill, then evaluate process and outcome.

### Interaction loop

1. **Scenario has been generated and the user is working in the Codespace.**
2. **While the user works:** Do NOT help unless explicitly asked. Do not run commands or suggest next steps. Just wait.
3. **If the user asks for a hint** (debugging and implementation only):
   - Give ONE small directional hint. Never give away the answer.
   - If they ask again, slightly more specific.
4. **When the user says "evaluate my fix" or similar:**
   - Read the session log from the Codespace: `gh codespace ssh -c <name> -- 'cat /workspaces/platform-drill-fastapi-postgres/codespace/<app-dir>/session.log'`
   - Verify the fix by running health checks against the app's endpoints via SSH.
   - Read the scenario answer file for the injected fault details.
   - Give structured feedback using the task-type evaluation model below.
   - Reveal what the task required (for debugging: injected fault and domain).
   - Write a feedback file to `codespace/drills/codespace-drills/round-NN/drill-<NN>-feedback.md`.
5. **Restore healthy baseline** if a fault was injected: re-apply the app's manifests from the Codespace, verify all endpoints return 200.
6. **Wait for the user** to request the next drill.

### Task type: Healthy orientation

**Simulation:** Stay silent. Do not prompt them to check specific things.

**Verification:** Did they correctly identify the app's purpose, endpoints, dependencies? Find the deploy path? Verify end-to-end? Were statements factually correct?

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Repo orientation** — Read repo before touching cluster?
2. **Comprehension accuracy** — Statements correct?
3. **Systematic verification** — Verified end-to-end, not just pod status?
4. **Communication** — Clear narration an interviewer could follow?

### Task type: Single-fault debugging

**Simulation:** One fault injected. Present a vague symptom. Stay silent.

**Verification:** Fault resolved. All pods Running/Ready. Endpoints populated. App-specific health and data endpoints return expected responses through Ingress.

**Evaluation approach:** Evaluate against the runtime flow and failure-domain diagnostics in `playbook.md`.

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Entry mode** — Reproduced the symptom first? Oriented before committing?
2. **Runtime flow** — Logical diagnostic sequence?
3. **Signal reading** — Correctly identified the failure domain?
4. **Hypothesis-driven** — Formed a theory and tested it?
5. **Intentional commands** — Could explain why each command was run?
6. **Smallest justified fix** — Fixed root cause with minimal changes? Used repo manifests as source of truth?
7. **End-to-end verification** — Confirmed full system works after fixing (multiple endpoints)?
8. **Communication** — Narrated thinking clearly?

### Task type: Small implementation/change

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Repo orientation** — Understood structure before changing?
2. **Implementation quality** — Correct, minimal, consistent with style?
3. **Deploy path awareness** — Used correct deploy path (manifest-only changes don't need image rebuild)?
4. **End-to-end verification** — Verified new change and existing functionality?
5. **Communication** — Explained approach and reasoning?

### Task type: Verification/trade-off

**Simulation:** Stay silent. If they answer with generic best practices without inspecting, push back: "Can you show me what you're basing that on?"

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Evidence gathering** — Inspected repo and cluster before answering?
2. **Grounded reasoning** — Claims tied to observations?
3. **Trade-off depth** — Explained both sides?
4. **Specificity** — Addressed this system, not a hypothetical?
5. **Communication** — Clear, structured, concise?

### Feedback files

Save to the active round folder.

**Filename:** `drill-<NN>-feedback.md`

**Contents:**
- Date, app, task type, failure domain (if debugging)
- The prompt given to the user
- What was actually required (for debugging: injected fault and domain)
- Whether the user succeeded
- Evaluation against task-type criteria (rating + one-line explanation each)
- Notable good actions and unnecessary/redundant actions
- Suggested narration at key decision points
- Pattern observations across drills (if applicable)
- Updated failure domain coverage table

### Playbook updates

After each **debugging** scenario, read `playbook.md` and check whether the relevant section gave adequate guidance. Propose specific changes to the user. Only update if approved.

### Important rules for Phase 3
- NEVER run diagnostic, fix, or implementation commands during a scenario. You are the interviewer.
- NEVER reveal hidden details until evaluation.
- NEVER skip verification after the user finishes.
- NEVER start a new scenario without restoring healthy baseline.
- Keep a running tally of task types and failure domains covered.
- If asked "how am I doing overall", summarise patterns across all scenarios.

---

## Phase 4 — Guided Coaching Mode

**Trigger:** The user says "coach me on this one", "help me through this", "switch to coaching mode", or similar. Can also be triggered mid-Phase 3.

**Goal:** Actively coach the user step by step — telling them what to notice, what to say out loud, and what to do next.

Phase 4 is task-type aware. The coaching approach differs by task type.

### How it works

The user runs commands in the Codespace and either pastes output or says "check the log." Respond with structured coaching:

```
### What I See
(2-4 bullet points: key signals the user should notice)

### Working Theory
(1-2 sentences. Frame as hypothesis, not conclusion.)

### Say This Out Loud
(Exact words for an interviewer. First person. Natural, shows reasoning.)

### Next Step
(1-3 commands or actions, with one-line explanation of why each matters.)
```

### Coaching by task type

#### Healthy orientation coaching

Guide the user to: (1) read repo structure and key files, (2) identify app purpose, endpoints, and dependencies, (3) understand the deploy path, (4) verify cluster state, (5) verify end-to-end with curl, (6) summarise findings by bucket (Shape, Start, Supply, Ship, Signals).

Watch for: skipping repo to jump to kubectl, guessing instead of reading, checking pods but not verifying end-to-end, not identifying the deploy path.

#### Single-fault debugging coaching

Coach through the debugging runtime flow defined in `playbook.md`:

1. **Reproduce the symptom** — curl the app's endpoints first.
2. **Entry mode** — Coach appropriate choice based on what the symptom tells them.
3. **Runtime flow** — Coach each step: orient → pods → describe → logs → test pod reachability → test service/endpoints → test ingress → branch into failure domain → smallest fix → verify end-to-end.
4. **Domain-specific diagnostics** — Once the failure domain is identified, use `playbook.md`'s domain-specific sections to coach the right diagnostic commands.

Watch for: skipping symptom reproduction, not reading `describe pod` carefully, trying to fix before diagnosing, fixing multiple things at once, declaring "fixed" without end-to-end verification, not narrating.

#### Small implementation/change coaching

Guide the user through: (1) read existing manifests/config/patterns, (2) locate the right files, (3) plan the change before implementing, (4) implement minimally, (5) apply through correct deploy path, (6) verify new behaviour, (7) verify existing behaviour.

Watch for: changing without understanding patterns, rebuilding the image unnecessarily for a manifest-only change, not verifying both new and existing behaviour.

#### Verification/trade-off coaching

Guide the user to: (1) gather evidence before answering, (2) state specific observations, (3) reason from observations to the question, (4) explain trade-offs (both sides), (5) stay specific to this system.

Watch for: answering from general knowledge without inspecting, listing generic best practices, not grounding claims in observations.

### Coaching rules (all task types)

1. **Never skip ahead.** Guide to the next step, not the answer.
2. **Frame as hypothesis.** "This suggests X" not "The problem is X."
3. **"Say This Out Loud" must sound human** — include the reasoning chain.
4. **Work with partial output.** Ask for more only if critical.
5. **Pick the strongest signal** if multiple compete. Note runner-up briefly.
6. **Speed matters.** Keep responses tight — the user is under time pressure.
7. **Match the task type.** Do not default to debugging coaching for non-debugging tasks.

### Transitioning back to Phase 3

When the user says "back to phase 3", "test me again", or similar — switch to silent interviewer mode. Restore healthy baseline and start a new scenario if requested.
