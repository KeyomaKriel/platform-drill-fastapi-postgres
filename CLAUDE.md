# Platform Drill — Operating Manual

## Purpose

This repo is a practice environment for a 60-minute hands-on Platform Engineer technical interview. The interview format is a **repo-based practical task in a prepared environment** (likely Codespaces or similar), with engineers observing and lightly guiding.

The candidate is allowed to use a browser and AI. The interview tests **systematic triage, repo orientation, debugging process, implementation quality, and communication** — not recall.

Kubernetes break/fix is one layer of this practice, not the whole frame. A strong candidate orients to the repo first, understands the intended run/deploy path, then operates on the cluster with that context.

---

## Environment

- Machine: Apple Silicon Mac
- **Drill system root**: The current working directory (the folder Claude Code is running in). All paths in this document are relative to this root unless stated otherwise.
- Container runtime: Docker Desktop
- Local cluster: kind (not EKS)
- No cloud registry — use `kind load docker-image`
- Required tools: Docker, kubectl, kind, helm

### Filesystem layout

```
./                              # Drill system root
├── CLAUDE.md                   # This operating manual
├── source-repo/                # Canonical template — read-only during drills
│   ├── app/                    # Application code
│   ├── Dockerfile
│   ├── k8s/                    # Kubernetes manifests
│   ├── requirements.txt
│   └── ...                     # Other candidate-facing project files
├── workspaces/                 # Disposable drill workspaces (gitignored)
│   └── drill-workspace-<NN>/   # One per drill, created fresh, deleted after eval
│       └── session.log         # Terminal capture for this drill
├── drills/
│   └── drill-feedback/         # Persistent feedback files across drills
├── playbook.md                 # Triage reference (updated after drills)
├── prompts/                    # Prompt drafts and notes
└── ...                         # Other drill-system supporting files
```

---

## Key Definitions

- **Drill system root**: The current working directory. All relative paths rooted here.
- **Source repo** (`./source-repo/`): Canonical template containing app code, Dockerfile, K8s manifests, and supporting project files. **Read-only during drills** — Claude Code and the user must not modify it during any drill. Phase 1 may read/build/deploy from it but must not mutate it.
- **Template baseline**: The known-good state established by Phase 1: source repo intact, app image built and loaded into kind, all K8s resources deployed and healthy in the `drill` namespace, all verification checks passing.
- **Scenario workspace** (`./workspaces/drill-workspace-<NN>/`): Fresh directory created per drill by copying from source repo. Disposable — deleted after evaluation. Never reused.
- **Healthy baseline**: All pods Running/Ready, endpoints populated, `curl localhost/`, `curl localhost/health`, and `curl localhost/items` all return expected responses through Ingress.
- **Reset path**: Restore cluster to healthy baseline, delete current workspace, clear session log.
- **Session log** (`./workspaces/drill-workspace-<NN>/session.log`): Terminal capture inside the workspace. Created fresh per drill. Read during evaluation. Deleted with workspace.
- **Drill artefacts** (`./drills/drill-feedback/`): Feedback files that survive workspace cleanup.

---

## App Details

FastAPI app with three endpoints:

- `GET /` — returns app name, version, hostname
- `GET /health` — returns 200 if Postgres is reachable, 503 if not
- `GET /items` — returns rows from a Postgres `items` table

The app reads Postgres connection details from environment variables: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`. It creates the `items` table and seeds two rows on startup. If Postgres is unreachable at startup, the app crashes (no retry).

The Dockerfile does not need a `--platform` flag — kind nodes match the host architecture (arm64 on Apple Silicon).

---

## Debug Terminal Setup

The user debugs scenarios in a **separate terminal** — not through Claude Code. To allow Claude Code to evaluate the user's triage process, the user must start a terminal session log at the beginning of each drill.

**After Phase 2 creates the workspace**, instruct the user:

> In your debug terminal, `cd` into the workspace and start the session log:
> ```
> cd <absolute-path-to-drill-system-root>/workspaces/drill-workspace-<NN>
> script -q -a ./session.log
> ```
> This captures all your commands and output. When you're done, come back here and say "evaluate my fix."

**The user does not need to manually clear the log between scenarios.** Workspace cleanup handles this.

---

## Phase 1 — Baseline Bootstrap and Verification

**Trigger:** The user says "run phase 1", "set up the environment", "bootstrap", or similar.

**Goal:** Establish or verify the template baseline — a stable, reusable, known-good foundation from which every drill starts.

Phase 1 supports two modes:

- **Full bootstrap:** Build everything from scratch (first run, or after teardown).
- **Fast health-check:** Verify that an existing baseline is still healthy, fix anything that isn't.

Phase 1 must be idempotent — safe to run repeatedly.

### Source repo rules during Phase 1

Phase 1 **reads from** `./source-repo/` to build images and deploy resources. It does **not** modify the source repo. Specifically:

- Build the Docker image from `./source-repo/Dockerfile`. Do not modify the Dockerfile.
- Deploy K8s resources as defined below. If the source repo contains manifest files, use them as-is. If not, generate and apply directly — do not write generated manifests back into the source repo.
- If Phase 1 needs supporting files (kind config, temporary YAML), use `./tmp/` or apply inline.

If the user explicitly asks to modify the source repo, that is a separate instruction outside Phase 1's scope.

### Step-by-step

1. **Check prerequisites.** Verify each is installed and available. If not, install it.
   - Docker (must be running — check `docker info`)
   - kubectl
   - kind
   - helm

2. **Create kind cluster** (if one named `drill-cluster` doesn't already exist).
   - Use a kind config that:
     - Maps container ports 80 and 443 to host for Ingress
     - Labels the control-plane node with `ingress-ready=true`
     - Uses one control-plane node (no workers needed)
   - After creation, verify `kubectl cluster-info` works

3. **Install CNI that supports NetworkPolicies.**
   - kindnet (the default) does NOT support NetworkPolicies. Install Calico instead.
   - Apply the Calico manifest and wait for calico pods to be ready.
   - Verify Calico is running before proceeding.

4. **Install nginx Ingress controller for kind.**
   - Use the kind-specific nginx ingress manifest.
   - Wait for the ingress-nginx-controller pod to be ready.
   - Verify it's running before proceeding.

5. **Build the app image.**
   - `docker build -t platform-drill-api:local ./source-repo/`
   - `kind load docker-image platform-drill-api:local --name drill-cluster`

6. **Create namespace** `drill` (if it doesn't exist).

7. **Deploy the full stack** into the `drill` namespace. Create all resources via kubectl or by generating and applying YAML. The stack must include ALL of the following:

   **Postgres:**
   - ConfigMap: `postgres-config` with `POSTGRES_DB=platformdrill`, `POSTGRES_USER=platformuser`
   - Secret: `postgres-secret` with `POSTGRES_PASSWORD=platformpass`
   - PersistentVolumeClaim: `postgres-pvc`, 1Gi, access mode ReadWriteOnce
   - Deployment: postgres:16, single replica, volume mount at `/var/lib/postgresql/data`, using the PVC, env from ConfigMap and Secret, readiness probe using `pg_isready`, liveness probe using `pg_isready`
   - Service: `postgres`, port 5432

   **App:**
   - ConfigMap: `app-config` with `POSTGRES_HOST=postgres`, `POSTGRES_PORT=5432`, `POSTGRES_DB=platformdrill`, `POSTGRES_USER=platformuser`
   - Secret: `app-secret` with `POSTGRES_PASSWORD=platformpass`
   - ServiceAccount: `app-sa`
   - Role: `app-role` — grant get/list/watch on pods and services in the `drill` namespace
   - RoleBinding: `app-rolebinding` — bind `app-role` to `app-sa`
   - Deployment: `platform-drill-api`, image `platform-drill-api:local`, imagePullPolicy `Never`, single replica
     - Uses ServiceAccount `app-sa`
     - env from ConfigMap and Secret via `envFrom`
     - Resource requests: 64Mi memory, 50m CPU
     - Resource limits: 128Mi memory, 200m CPU
     - Readiness probe: GET /health port 8000, initialDelaySeconds 5, periodSeconds 5
     - Liveness probe: GET /health port 8000, initialDelaySeconds 15, periodSeconds 10
     - Init container: busybox that waits for Postgres to be reachable on port 5432 before the main container starts. Use a simple loop with `nc -z postgres 5432`.
   - Service: `platform-drill-api`, port 80, targetPort 8000

   **Ingress:**
   - Ingress resource: `app-ingress`, IngressClass `nginx`
   - Route `/` to service `platform-drill-api` on port 80

   **NetworkPolicies:**
   - `default-deny-ingress`: deny all ingress traffic in the namespace by default
   - `allow-app-from-ingress`: allow ingress to the app pods from the ingress-nginx namespace
   - `allow-postgres-from-app`: allow ingress to postgres pods from app pods only
   - `allow-app-to-postgres`: allow egress from app pods to postgres pods on port 5432
   - `allow-dns`: allow egress to kube-system for DNS resolution from all pods

8. **Wait and verify everything is healthy.**
   - All pods Running and Ready
   - `kubectl get endpoints -n drill` shows populated endpoints for both services
   - `curl localhost/` returns the app response through Ingress
   - `curl localhost/health` returns 200
   - `curl localhost/items` returns the two seeded items
   - If any verification fails, diagnose and fix before reporting success.

9. **Report the final state.**
   - Show `kubectl get all -n drill`
   - Show `kubectl get ingress -n drill`
   - Show `kubectl get networkpolicy -n drill`
   - Show the curl outputs
   - Confirm: "Phase 1 complete. Template baseline is healthy and ready for drills."

### Important rules for Phase 1
- Be idempotent. Check before creating. Don't fail if something already exists.
- If anything fails during setup, diagnose and fix it. Do not just report the error and stop.
- Do not modify `./source-repo/`. Build from it, deploy from it, but leave it unchanged.
- Do not proceed to Phase 2 automatically. Wait for the user to trigger it.
- If previous scenario workspaces exist under `./workspaces/`, delete them during Phase 1 to ensure a clean state.

---

## Phase 2 — Scenario Workspace Generation

**Trigger:** The user says "start phase 2", "next scenario", "start drill", "new drill", or similar.

**Goal:** Create a fresh scenario workspace for the current drill from the healthy template baseline, and prepare a realistic interview-style task for the user to work on.

### Pre-flight checks

1. **Verify the template baseline is healthy.** Run the same verification as Phase 1 step 8. If unhealthy, restore before proceeding.
2. **Clean up any previous scenario workspace.** Delete any existing directories under `./workspaces/`.

### Scenario workspace creation

1. **Create the workspace directory.** Use `./workspaces/drill-workspace-<NN>` where `<NN>` is the scenario number (zero-padded). If it already exists, delete it first.

2. **Copy candidate-facing project contents from `./source-repo/`.**

   Use `rsync` (or equivalent) with an **exclude-list approach**: copy everything, excluding:
   - `.git/`, `session.log`, `drill-session.log`, `*.log`, `.DS_Store`

   Everything else is assumed candidate-facing and must be copied.

3. **Set up git history in the workspace** so `git log`, `git diff`, and `git status` work realistically.

   **Algorithm:**
   1. `cd` into workspace, `git init`.
   2. List actual top-level files/directories.
   3. Sort into 2-4 logical groups (app code, infra/deploy config, docs/other). Inspect contents per run — do not hard-code.
   4. For each group, `git add` and commit with realistic message and backdated `--date`.

   **Grouping heuristic:**
   - **Group 1 — App code and deps:** Source code, dependency files, Dockerfiles, `.dockerignore`, `.gitignore`. Message: `"Initial application setup"`. Date: 3 days ago.
   - **Group 2 — Infra/deploy config:** Manifests, Helm charts, compose files, CI config, deploy scripts. Message: `"Add deployment configuration"`. Date: 2 days ago.
   - **Group 3 — Everything else:** `git add -A` to catch remaining. Message: `"Add documentation and project config"`. Date: 1 day ago.

   Skip group 3 if groups 1-2 cover everything.

4. **Do not modify `./source-repo/`.**

### Task types

Each drill uses one of these task types:

#### 1. Healthy orientation task
- **No fault injected.** Cluster is healthy.
- Prompt: "Walk me through what this application does, how it's deployed, and how you'd verify it's working."
- Tests: repo reading, manifest comprehension, systematic verification, communication.

#### 2. Single-fault debugging task
- **One fault injected** into the live cluster (not workspace files).
- User gets a vague symptom. Must discover the problem through runtime behaviour.
- Tests: triage process, signal reading, hypothesis-driven debugging, fix quality.
- See Phase 3 for fault injection mechanics and failure domains.

#### 3. Small implementation/change task
- **No fault injected.** Cluster is healthy.
- User makes a small, realistic change and deploys it.
- **Constraints:** Completable in 10-15 minutes. Must involve code/config/manifest change + build/deploy/verify. Prefer realistic tasks (adding an endpoint, updating config, adjusting a manifest). Do not invent tasks requiring deep domain knowledge or major infrastructure buildout.
- Examples: add a `/ready` endpoint and update the readiness probe; add a `version` label to all pods; add a startup probe; move a hardcoded password to a Secret; add a `/version` endpoint from an env var.

#### 4. Verification/trade-off task
- **No fault injected.** Cluster is healthy.
- User evaluates something about the current setup. Must inspect before answering — generic best practices without evidence are not acceptable.
- **Constraints:** Answerable by inspecting this repo and deployment. Push for specifics, not checklists.
- Examples: review resource limits; walk through what happens when Postgres dies; assess production-readiness; investigate a reported performance issue.

### Drill scope and coverage model

**Primary focus (dominate drill generation):**
- Single-fault debugging of app, deployment, and runtime issues
- Repo orientation
- Small practical changes (code, config, manifests)
- Evidence-based verification and trade-off reasoning

**Secondary focus (occasionally, ~1 in 4 drills):**
- Infra-adjacent tasks: probe tuning, resource limits, labels, startup behaviour
- Manifest-level additions that fit existing patterns

**Out of scope (unless user requests):**
- Deep cluster internals (CNI, node-level, control-plane)
- Multi-root-cause scenarios
- Major infrastructure buildout (service meshes, monitoring, CI/CD, GitOps)
- Advanced platform features not in the repo

### Task selection rules

1. **First drill:** Always healthy orientation.
2. **Second drill onward:**
   a. Don't repeat the same task type consecutively (unless requested).
   b. ~50-60% debugging tasks.
   c. Interleave implementation and verification between debugging drills.
   d. After three debugging tasks in a row, insert a non-debugging task.
   e. Honour explicit user requests.
3. **Track and report** task types and failure domains when asked.

### How to prepare the task

1. **Select task type** per selection rules.
2. **If debugging**, inject fault now (see Phase 3).
3. **Present as a realistic interview prompt.** Use the absolute workspace path. Frame as if the user just sat down at a workstation.
4. **Instruct the user to start the session log:**
   ```
   cd <absolute-path>/workspaces/drill-workspace-<NN> && script -q -a ./session.log
   ```
5. **STOP. Wait for the user to work.**

### Workspace cleanup

After evaluation:
- Delete the workspace directory.
- Restore cluster to healthy baseline if a fault was injected.
- Verify healthy baseline before the next drill.

### Important rules for Phase 2
- Never reuse a previous workspace. Always create fresh.
- Never modify `./source-repo/` during a drill.
- The workspace must feel like a coherent interview repo, not a test harness.
- If user says "just break something", skip workspace creation — fall through to Phase 3 directly. Session log falls back to `./drill-session.log` at the drill system root.
- Track which task types and failure domains have been used.

---

## Phase 3 — Interview Simulation and Evaluation

**Trigger:** Entered from Phase 2 after a task is presented, or directly if the user says "just break something" or "test me".

**Goal:** Act as a technical interviewer across all task types. Observe silently, then evaluate process and outcome.

### Interaction loop (all task types)

1. **Task has been presented.**
2. **While the user works:** Do NOT help unless explicitly asked. Do not run commands or suggest next steps. Just wait.
3. **If the user asks for a hint** (debugging and implementation only):
   - Give ONE small directional hint. Never give away the answer.
   - If they ask again, slightly more specific.
4. **When the user says they've finished:**
   - Read the session log.
   - Run verification checks for the task type.
   - Give structured feedback using the task-type evaluation model.
   - Reveal what the task required (for debugging: injected fault and domain).
   - Write a feedback file.
   - For debugging: propose playbook updates if applicable.
5. **Clean up:** Delete workspace, restore healthy baseline if needed, verify before next drill.
6. **Wait for "next scenario"** before starting the next drill.

**"Just break something" fallback:** Session log at `./drill-session.log` at drill system root.

---

### Task type: Healthy orientation

**Simulation:** Stay silent. Do not prompt them to check specific things.

**Verification:** Did they correctly identify the app's purpose, endpoints, dependencies? Find the deploy path? Verify end-to-end? Were statements factually correct?

**What good looks like:** Repo orientation first (read files, identify components). Identified app purpose, endpoints, DB dependency. Found deploy path. Verified cluster state and end-to-end responses. Narrated clearly.

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Repo orientation** — Read repo before touching cluster?
2. **Comprehension accuracy** — Statements correct?
3. **Systematic verification** — Verified end-to-end, not just pod status?
4. **Communication** — Clear narration an interviewer could follow?

---

### Task type: Single-fault debugging

**Simulation:** One fault injected. Present a vague symptom. Stay silent.

**Verification:** Fault resolved. All pods Running/Ready. Endpoints populated. All three curl tests pass.

**Evaluation approach:** Evaluate the user's debugging process against the runtime flow and failure-domain diagnostics defined in `playbook.md`. The playbook contains the detailed step-by-step debugging flow, entry modes, signal-to-domain mapping, and bucket-specific diagnostic commands. Use those as the evaluation rubric.

**What good looks like:** Chose appropriate entry mode. Followed a logical diagnostic sequence. Oriented to both repo and cluster. Read signals correctly and committed to the right failure domain. Formed and tested a hypothesis. Applied the smallest fix. Verified end-to-end. Narrated throughout.

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Entry mode** — Appropriate choice between triage and fast path? Oriented before committing?
2. **Runtime flow** — Logical diagnostic sequence (orient → pods → describe → logs → test reachability → test service → test ingress → branch)?
3. **Signal reading** — Correctly identified the failure domain?
4. **Hypothesis-driven** — Formed a theory and tested it, or tried randomly?
5. **Intentional commands** — Could explain why each command was run?
6. **Smallest justified fix** — Fixed root cause with minimal changes?
7. **End-to-end verification** — Confirmed full system works after fixing?
8. **Communication** — Narrated thinking clearly?

#### Failure domains for debugging tasks

Each scenario uses one failure domain. Track which have been used and rotate through all before repeating.

| # | Failure domain |
|---|---------------|
| 1 | Startup / crash failure |
| 2 | Image pull / container creation failure |
| 3 | Probe failure |
| 4 | Config / Secret / env failure |
| 5 | Service routing / port / endpoint failure |
| 6 | DNS / service discovery / namespace failure |
| 7 | Resource / scheduling / storage failure |
| 8 | Ingress / external routing failure |
| 9 | NetworkPolicy / traffic restriction failure |
| 10 | RBAC / service account / permission failure |
| 11 | Application-level dependency / runtime failure |

For detailed subcases, diagnostic commands, signal-to-domain mapping, and fix patterns for each domain, refer to `playbook.md`.

#### How to inject a fault

**CRITICAL: The user must NOT see what you are breaking.** Claude Code shows an approval prompt for every command.

**Always base64-encode the break commands:**

```bash
echo "<base64-encoded-commands>" | base64 -d | bash
```

The approval prompt shows `echo "gibberish" | base64 -d | bash` — the user cannot read the commands.

**Include verification commands** in the same encoded payload to confirm the fault is manifesting. Do NOT run verification as separate visible commands.

**Rules:**
- Use `kubectl` commands (patch, set image, delete, apply) to break something in the running cluster.
- Only break ONE thing per scenario.
- Record exactly what you did internally so you can evaluate the user's fix later. Do NOT write this record to a file the user can read.

---

### Task type: Small implementation/change

**Simulation:** Stay silent. Do not suggest approaches unless asked.

**Verification:** Change correct? Minimal and consistent with repo patterns? Image rebuilt, redeployed, verified live? Existing endpoints still functional?

**What good looks like:** Oriented to repo first. Found the right place to change. Minimal, correct implementation. Executed full build/deploy cycle. Verified new and existing behaviour. Communicated clearly.

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Repo orientation** — Understood structure and patterns before changing?
2. **Implementation quality** — Correct, minimal, consistent with style?
3. **Deploy path awareness** — Built, loaded, deployed without floundering?
4. **End-to-end verification** — Verified new change and existing functionality?
5. **Communication** — Explained approach and reasoning?

---

### Task type: Verification/trade-off

**Simulation:** Stay silent while user investigates. If they answer with generic best practices without inspecting anything, push back: "Can you show me what you're basing that on?"

**Verification:** Did they inspect before answering? Claims factually grounded? Addressed the specific question, not a generic version?

**What good looks like:** Inspected before reasoning. Grounded every claim in a specific observation. Identified specific gaps/risks. Explained trade-offs with both sides. Addressed this specific system.

**Evaluation criteria (Needs Work / Solid / Strong):**
1. **Evidence gathering** — Inspected repo and cluster before answering?
2. **Grounded reasoning** — Claims tied to observations, not generic?
3. **Trade-off depth** — Explained both sides?
4. **Specificity** — Addressed this system, not a hypothetical?
5. **Communication** — Clear, structured, concise?

---

### Feedback files

Save to `./drills/drill-feedback/`. Create the directory if it doesn't exist.

**Filename:** `scenario-<NN>-<slug>.md` (slug: `orientation`, failure domain slug, short task description, or short question description).

**Contents:**
- Scenario number, date/time, task type
- The prompt given to the user
- What was actually required (for debugging: injected fault and domain)
- Whether the user succeeded
- Evaluation against task-type criteria (rating + one-line explanation each)
- Notable good actions and unnecessary/redundant actions
- Suggested narration at key decision points

### Playbook updates

After each **debugging** scenario, read `playbook.md` and check whether the relevant section gave adequate guidance. Look for:
- Missing/weak output-reading guidance, commands, signals, or fix patterns
- Too-fast diagnosis-to-fix jumps, weak narration examples, incorrect content

Propose specific changes to the user. Only update if approved. Never reorganize the document.

Not required for non-debugging tasks, but note patterns if the user repeatedly struggles with repo orientation or deploy-path awareness.

### Important rules for Phase 3
- NEVER run diagnostic, fix, or implementation commands during a scenario. You are the interviewer.
- NEVER reveal hidden details in the initial prompt.
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

The user runs commands in their debug terminal and either pastes output or says "check the log." Respond with structured coaching:

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

Adapt content to the task type: "Next Step" may be "read this file" for orientation, "edit this file" for implementation, "inspect this manifest" for verification.

### Coaching by task type

#### Healthy orientation coaching

Guide the user to: (1) read repo structure and key files, (2) identify app purpose, endpoints, and dependencies, (3) understand the deploy path, (4) verify cluster state, (5) verify end-to-end with curl, (6) summarise findings.

Watch for: skipping repo to jump to kubectl, guessing instead of reading, checking pods but not verifying end-to-end, not identifying the deploy path.

#### Single-fault debugging coaching

Coach through the debugging runtime flow defined in `playbook.md`:

1. **Entry mode** — Coach appropriate choice (full triage if scope unclear, fast path if workload known, hybrid as default).
2. **Runtime flow** — Coach each step: orient (repo + cluster context) → identify workload → check pod state → describe pod → check logs → test pod reachability → test service/endpoints → test ingress → branch into failure domain → smallest fix → verify end-to-end.
3. **Domain-specific diagnostics** — Once the failure domain is identified, use `playbook.md`'s domain-specific sections to coach the right diagnostic commands.

Watch for: skipping orientation, not reading `describe pod` carefully, trying to fix before diagnosing, fixing multiple things at once, declaring "fixed" without end-to-end verification, not narrating.

#### Small implementation/change coaching

Guide the user through: (1) read existing code/manifests/patterns, (2) locate the right files, (3) plan the change before implementing, (4) implement minimally, (5) build/load/deploy cycle, (6) verify new behaviour, (7) verify existing behaviour.

Watch for: changing without understanding patterns, forgetting to rebuild image, forgetting to reload into kind, not verifying both new and existing behaviour, over-engineering.

#### Verification/trade-off coaching

Guide the user to: (1) gather evidence before answering, (2) state specific observations, (3) reason from observations to the question, (4) explain trade-offs (both sides), (5) stay specific to this system.

Watch for: answering from general knowledge without inspecting, listing generic best practices, not explaining trade-offs, not grounding claims in observations.

### Coaching rules (all task types)

1. **Never skip ahead.** Guide to the next step, not the answer.
2. **Frame as hypothesis.** "This suggests X" not "The problem is X."
3. **"Say This Out Loud" must sound human** — include the reasoning chain.
4. **Work with partial output.** Ask for more only if critical.
5. **Pick the strongest signal** if multiple compete. Note runner-up briefly.
6. **Speed matters.** Keep responses tight — the user is under time pressure.
7. **Match the task type.** Do not default to debugging coaching for non-debugging tasks.

### Transitioning back to Phase 3

When the user says "back to phase 3", "test me again", or similar — switch to silent interviewer mode. If a scenario was in progress, restore healthy baseline and start a new one.
