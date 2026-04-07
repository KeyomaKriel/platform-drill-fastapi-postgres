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

These terms are used precisely throughout this document.

- **Drill system root**: The current working directory. All relative paths in this document are rooted here.
- **Source repo** (`./source-repo/`): A manually curated canonical template containing the app code, Dockerfile, Kubernetes manifests, and supporting project files. The source repo is **read-only during drills** — Claude Code and the user must not modify it as part of any drill. Phase 1 may read from it, build from it, deploy from it, and verify against it. Phase 1 may not rewrite, regenerate, restructure, or mutate the source repo unless the user explicitly instructs it to do so outside of a drill context.
- **Template baseline**: The known-good state established by Phase 1. It includes: source repo intact and unmodified, app image built and loaded into kind, all Kubernetes resources deployed and healthy in the `drill` namespace, all verification checks passing. This is the reusable foundation from which every drill starts.
- **Scenario workspace** (`./workspaces/drill-workspace-<NN>/`): A fresh directory created for each drill by copying candidate-facing contents from the source repo. The user works exclusively inside this workspace. It is disposable — deleted after evaluation. Each drill gets a new workspace; workspaces are never reused across drills.
- **Healthy baseline**: The cluster state where all pods are Running/Ready, endpoints are populated, and `curl localhost/`, `curl localhost/health`, and `curl localhost/items` all return expected responses through Ingress.
- **Reset path**: The process of restoring the cluster to healthy baseline, deleting the current scenario workspace, and clearing the session log, so the next drill starts clean.
- **Session log** (`./workspaces/drill-workspace-<NN>/session.log`): Terminal capture file inside the current scenario workspace. Captures the user's commands and output during a drill. Created fresh per workspace. Read by Claude Code during evaluation. Deleted with the workspace after evaluation.
- **Drill artefacts** (`./drills/drill-feedback/`): Feedback files and other persistent outputs. These survive workspace cleanup because they are reference material, not drill state.

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

The session log lives inside the scenario workspace at `./workspaces/drill-workspace-<NN>/session.log`. It is created fresh per drill and deleted with the workspace after evaluation.

**The user does not need to manually clear the log between scenarios.** Workspace cleanup handles this.

---

## Phase 1 — Baseline Bootstrap and Verification

**Trigger:** The user says "run phase 1", "set up the environment", "bootstrap", or similar.

**Goal:** Establish or verify the template baseline — a stable, reusable, known-good foundation from which every drill starts.

This phase builds and deploys the specific stack defined below. This stack is the canonical baseline implementation chosen for this practice system. It is not intended to represent the exact interview environment — it is designed to reproduce the key behaviours that matter: entering an unfamiliar repo, inspecting a Kubernetes-deployed app, debugging it, making changes, and verifying them.

Phase 1 supports two modes:

- **Full bootstrap:** Build everything from scratch (first run, or after teardown).
- **Fast health-check:** Verify that an existing baseline is still healthy, fix anything that isn't.

Phase 1 must be idempotent — safe to run repeatedly.

### Source repo rules during Phase 1

Phase 1 **reads from** `./source-repo/` to build images and deploy resources. It does **not** modify the source repo's files, directory structure, or content. Specifically:

- Build the Docker image from `./source-repo/Dockerfile`. Do not modify the Dockerfile.
- Deploy Kubernetes resources as defined below. If the source repo contains manifest files, use them as-is. If it does not, generate manifests and apply them directly to the cluster — do not write generated manifests back into the source repo.
- If Phase 1 needs to create supporting files (kind config, temporary YAML), use `./tmp/` or apply them inline. Do not add files to the source repo.

If the user explicitly asks to modify the source repo (e.g., "update the Dockerfile", "add a manifest"), that is a separate instruction outside Phase 1's scope. Comply, but do not conflate it with baseline setup.

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

Before generating a scenario:

1. **Verify the template baseline is healthy.** Run the same verification as Phase 1 step 8 (pods Running/Ready, endpoints populated, curl tests passing). If the baseline is unhealthy, restore it before proceeding. Do not generate a scenario on top of a broken baseline.
2. **Clean up any previous scenario workspace.** Delete any existing directories under `./workspaces/`.

### Scenario workspace creation

Create a fresh, isolated workspace that feels like a prepared interview repo the user is entering for the first time.

1. **Create the workspace directory.** Use `./workspaces/drill-workspace-<NN>` where `<NN>` is the scenario number (zero-padded, e.g., `01`). If the directory already exists, delete it first.

2. **Copy candidate-facing project contents from `./source-repo/`.**

   Use `rsync` (or equivalent) with an **exclude-list approach**: copy everything from `./source-repo/`, excluding files that are not part of the candidate-facing project.

   **Exclude from the workspace** (drill infrastructure, not project files):
   - `.git/` (the source repo's git history, if any — see step 3 for workspace git setup)
   - `session.log`, `drill-session.log`, or any `*.log` files
   - `.DS_Store`

   **Everything else in `./source-repo/` is assumed to be candidate-facing** and must be copied. This includes application code, Dockerfiles, manifests, dependency files, config files, READMEs — whatever the source repo contains.

   **Rule of thumb:** The source repo should only contain files that belong in a realistic interview repo. If a file should not be handed to a candidate, it should not be in `./source-repo/` in the first place — it belongs at the drill system root instead.

3. **Set up git history in the workspace** so `git log`, `git diff`, and `git status` work realistically.

   The workspace should feel like a real repo with natural history, not a freshly initialised repo with one synthetic commit.

   **Algorithm:**
   1. `cd` into the workspace and run `git init`.
   2. List the actual top-level files and directories in the workspace.
   3. Sort them into 2-4 logical groups based on what they are (application code, infrastructure/deploy config, documentation/other). Do not hard-code group membership — inspect the workspace contents and decide per run.
   4. For each group, `git add` those paths and commit with a realistic message and a backdated `--date`. Use `--allow-empty` on later commits in case earlier groups already covered everything.

   **Grouping heuristic** (apply by inspecting what actually exists, not by assuming fixed paths):
   - **Group 1 — Application code and dependencies:** Source code directories, dependency/lock files, Dockerfiles, `.dockerignore`, `.gitignore`. Commit message like `"Initial application setup"`. Date: 3 days ago.
   - **Group 2 — Infrastructure and deploy config:** Manifest directories, Helm charts, compose files, CI config, deploy scripts — anything that describes how to build/run/deploy. Commit message like `"Add deployment configuration"`. Date: 2 days ago.
   - **Group 3 — Everything else:** READMEs, docs, remaining config files. `git add -A` to catch anything not yet staged. Commit message like `"Add documentation and project config"`. Date: 1 day ago.

   If the workspace is small enough that groups 1 and 2 cover everything, skip group 3. The goal is natural-looking history, not a fixed number of commits.

4. **Do not modify `./source-repo/`.** The workspace is a copy. The source repo must remain unchanged.

### Task types

Each drill uses one of these task types. The task type determines what the user is asked to do and how they are evaluated.

#### 1. Healthy orientation task
- **No fault injected.** The cluster is healthy.
- The user is given a vague orientation prompt: "You've just been given access to this repo and the running environment. Walk me through what this application does, how it's deployed, and how you'd verify it's working correctly."
- Tests: repo reading, manifest comprehension, systematic verification, communication.
- Evaluation: Did they read the repo before touching the cluster? Did they identify the app's purpose, endpoints, dependencies? Did they verify end-to-end?

#### 2. Single-fault debugging task
- **One fault injected** into the running cluster (using the fault injection mechanics defined in Phase 3).
- The user is given a vague symptom.
- The fault is injected into the **live cluster**, not into the workspace files. The user should discover the problem through runtime behaviour, not by diffing files against a known-good state.
- Tests: triage process, signal reading, hypothesis-driven debugging, fix quality.
- See Phase 3 for the full interaction loop, failure domains, and fault injection mechanics.

#### 3. Small implementation/change task
- **No fault injected.** The cluster is healthy.
- The user is asked to make a small, realistic change and deploy it.
- **Realism constraints:**
  - The task must be completable in 10-15 minutes by a competent engineer who is seeing the repo for the first time.
  - The task must involve a change to the repo (code, config, or manifests) followed by a build/deploy/verify cycle.
  - Prefer tasks that a real team might ask in a pairing session or interview: adding an endpoint, updating a config value, adjusting a manifest, adding a label. Do not invent tasks that require deep domain knowledge the user would not have from reading the repo.
  - Do not ask for platform-heavy tasks that go beyond what the repo already supports (e.g., do not ask to set up a service mesh, add Prometheus, or configure CI/CD unless the repo already has those patterns).
- Examples:
  - "Add a new endpoint `GET /ready` that returns 200 with `{\"ready\": true}` and update the readiness probe to use it."
  - "The team wants to add a `version` label to all pods. Update the manifests and redeploy."
  - "The app currently has no startup probe. Add one and explain why it's useful here."
  - "The database password is hardcoded in the manifests. Move it to a Kubernetes Secret and update the deployment to reference it."
  - "Add a `/version` endpoint that returns the app version from an environment variable, and set that variable in the deployment manifest."
- Tests: repo comprehension, implementation quality, deployment process, verification.
- Evaluation: Did they understand where to make the change? Was the implementation correct and minimal? Did they rebuild, redeploy, and verify end-to-end?

#### 4. Verification/trade-off task
- **No fault injected.** The cluster is healthy, but the user is asked to evaluate something about the current setup.
- **Evidence requirement:** The user must inspect the repo and/or the running cluster before answering. High-level opinions without investigation are not acceptable. The evaluation must check whether the user gathered evidence before reasoning.
- **Realism constraints:**
  - The question must be answerable by inspecting this repo and its running deployment. Do not ask questions that require external context the user cannot access.
  - Prefer questions a senior engineer or interviewer would ask to test depth: "Is this production-ready?", "What happens when X fails?", "Are these resource limits appropriate?"
  - Do not accept generic best-practice answers. Push for specifics grounded in what the user actually observed.
- Examples:
  - "Review the current resource limits. Are they appropriate? What would you change and why?"
  - "Walk me through what happens if the Postgres pod dies. How does the app handle it? Show me."
  - "Is this deployment production-ready? What's missing? Be specific to what you see."
  - "A developer says responses are slow. Walk me through how you'd investigate — show your work."
- Tests: evidence-based reasoning, architectural understanding, communication depth.
- Evaluation: Did they inspect before answering? Was their reasoning grounded in specific observations from the repo and cluster? Did they communicate trade-offs clearly rather than listing generic best practices?

### Drill scope and coverage model

This section defines what kinds of tasks drills should generate. Use it to keep task generation aligned to realistic interview practice.

**Primary focus — should dominate drill generation:**
- Single-fault debugging of app, deployment, and runtime issues in Kubernetes
- Repo orientation (understanding an unfamiliar codebase and its deploy path)
- Small practical repo, config, or deployment changes (code edits, manifest adjustments, config tweaks)
- Evidence-based verification and trade-off reasoning grounded in the repo and cluster

**Secondary focus — may appear occasionally when they fit the repo and task naturally:**
- Infra-adjacent tasks such as probe tuning, resource limit adjustments, label management, startup behaviour changes
- Manifest-level additions or adjustments (e.g., adding a new resource type that the repo's existing patterns support)

Secondary tasks should not appear more than roughly once per four drills. Only use them when they feel like a natural extension of the repo, not a detour into platform engineering exercises.

**Out of scope — do not use unless the user explicitly requests:**
- Deep cluster internals (CNI debugging, node-level issues, control-plane troubleshooting)
- Multi-root-cause chaos scenarios (only one fault per debugging drill)
- Major infrastructure buildout (service meshes, monitoring stacks, CI/CD pipelines, GitOps)
- Advanced platform features not already present in the repo (custom operators, admission webhooks, etc.)
- Long architecture or system-design discussions disguised as drills

**Operational rule:** When generating a task, check it against this model. If the task falls outside primary focus, confirm it fits secondary focus before using it. If it falls outside both, do not use it unless the user asked for it. Keep drill grain close to what a 60-minute practical interview would realistically contain.

### Task selection rules

1. **First drill:** Always use a healthy orientation task. The user needs to learn the repo before debugging or implementing.
2. **Second drill onward:** Choose based on these rules, in priority order:
   a. Do not repeat the same task type as the previous drill, unless the user explicitly requests it.
   b. Prefer single-fault debugging tasks as the most common type — they are the core interview skill. Aim for roughly 50-60% of drills to be debugging tasks.
   c. Interleave implementation and verification tasks between debugging drills to vary the cognitive demand.
   d. If the user has done three or more debugging tasks in a row, insert a non-debugging task next.
   e. If the user requests a specific task type or failure domain, honour that request regardless of these rules.
3. **Track and report:** Maintain a running count of task types used and failure domains covered. Report when asked.

### How to prepare the task

1. **Select the task type** using the task selection rules above.
2. **If the task type requires a fault**, inject it now using the fault injection mechanics defined in Phase 3. Do not inject faults for orientation, implementation, or verification tasks.
3. **Present the task** to the user as a realistic interview prompt. Frame it as if the user has just sat down at a workstation and been given instructions by an interviewer. Use the **absolute path** to the workspace so the user can `cd` directly. Examples:
   - "Welcome. This repo contains a service that's deployed to the cluster. A developer reported that the API is returning errors. Your workspace is at `<absolute-path>/workspaces/drill-workspace-01`. Take a look and see what's going on."
   - "Welcome. You've been given access to this repo and its running environment. Walk me through the application, how it's deployed, and verify that everything is working. Your workspace is at `<absolute-path>/workspaces/drill-workspace-01`."
   - "Welcome. The team wants you to add a `/version` endpoint. The repo is at `<absolute-path>/workspaces/drill-workspace-01`. Implement it and deploy it to the cluster."
4. **Tell the user their workspace path.** Always explicitly state the absolute path.
5. **Instruct the user to start the session log** in their debug terminal:
   ```
   cd <absolute-path>/workspaces/drill-workspace-<NN> && script -q -a ./session.log
   ```
6. **STOP. Wait for the user to work.**

### Workspace cleanup

After a drill is evaluated (in Phase 3), the scenario workspace is disposable. Clean it up:
- Delete the workspace directory (`rm -rf ./workspaces/drill-workspace-<NN>`).
- Restore the cluster to healthy baseline if a fault was injected.
- Verify the healthy baseline before the next drill.

### Important rules for Phase 2
- Never reuse a previous scenario workspace. Always create a fresh one.
- Never modify `./source-repo/` as part of a drill. All user work happens in the workspace.
- The workspace must feel like a coherent interview repo, not a test harness or lab environment.
- If the user asks to skip workspace creation and just inject a fault (e.g., "just break something"), that is acceptable — fall through to Phase 3's single-fault debugging mode directly, without creating a workspace. In this case, the session log falls back to `./drill-session.log` at the drill system root (instruct the user to start `script` there).
- Track which task types and failure domains have been used. Vary them according to the selection rules.

---

## Phase 3 — Interview Simulation and Evaluation

**Trigger:** Entered automatically from Phase 2 after a task is presented, or directly if the user says "just break something" or "test me".

**Goal:** Act as a technical interviewer across all task types. Observe the user's work silently, then evaluate their process and outcome based on what the task type actually tests.

Phase 3 handles four task types. Each has its own simulation behaviour, verification criteria, and evaluation model. The sections below define the shared interaction loop first, then the task-type-specific details.

---

### Interaction loop (all task types)

1. **The task has been presented** (by Phase 2, or directly as a debugging task if the user said "just break something").
2. **While the user works:** Do NOT help unless the user explicitly asks. Do not run commands. Do not suggest next steps. Just wait.
3. **If the user asks for a hint** (debugging and implementation tasks only):
   - Give ONE small directional hint. Example: "What namespace are you looking at?" or "Have you checked the endpoints?"
   - If they ask for another, give a slightly more specific one.
   - Never give away the answer directly.
4. **When the user says they've finished or asks for evaluation:**
   - Read the session log at `./workspaces/drill-workspace-<NN>/session.log`.
   - Run the verification checks for the task type (see task-type sections below).
   - Tell them whether their work met the task requirements.
   - Give structured feedback using the evaluation model for the task type.
   - Reveal what the task actually required (for debugging: the injected fault and domain).
   - Write a feedback file (see Feedback Files below).
   - For debugging tasks: propose playbook updates if applicable (see Playbook Updates below).
5. **Clean up:** Delete the scenario workspace (`rm -rf ./workspaces/drill-workspace-<NN>`). If a fault was injected, restore the cluster to healthy baseline. Verify healthy baseline before the next drill.
6. **Wait for the user to say "next scenario"** before starting the next drill.

**Fallback for "just break something" mode:** If no workspace was created, the session log falls back to `./drill-session.log` at the drill system root — instruct the user to start `script -q -a ./drill-session.log` there. All other Phase 3 behaviour applies normally.

---

### Task type: Healthy orientation

**Simulation behaviour:**
- No fault injected. The cluster is healthy.
- Stay silent while the user explores the repo and cluster.
- Do not prompt them to check specific things. Let them demonstrate their own orientation process.

**Verification checks:**
- Did the user correctly identify the app's purpose, endpoints, and dependencies?
- Did they find the Dockerfile, manifests, and deploy path?
- Did they verify the app end-to-end (curl or equivalent against the running deployment)?
- Were their statements about the system factually correct?

**What good performance looks like:**
- Started with repo orientation: read files, identified key components (app code, Dockerfile, manifests, config).
- Identified the app's purpose, endpoints, and database dependency without guessing.
- Found and understood the deploy path (build image, load into kind, apply manifests or deploy).
- Moved to cluster verification: checked pods, services, ingress, endpoints.
- Verified end-to-end: hit the actual endpoints and confirmed correct responses.
- Communicated clearly: narrated findings as they went, summarised coherently at the end.
- Did not randomly wander or run commands without purpose.

**Evaluation criteria (rate each: Needs Work / Solid / Strong):**
1. **Repo orientation** — Did they read the repo structure and key files before touching the cluster?
2. **Comprehension accuracy** — Were their statements about the app, its dependencies, and its deploy path correct?
3. **Systematic verification** — Did they verify end-to-end, not just glance at pod status?
4. **Communication** — Did they narrate clearly? Would an interviewer follow their reasoning?

---

### Task type: Single-fault debugging

**Simulation behaviour:**
- One fault injected into the live cluster before the task is presented.
- Present a vague symptom. Do NOT hint at the failure domain.
- Stay silent while the user debugs. Do not run commands or suggest next steps.

**Verification checks:**
- Is the fault resolved? (Specific to what was broken.)
- All pods Running and Ready.
- Endpoints populated for all services.
- `curl localhost/`, `curl localhost/health`, and `curl localhost/items` all return expected responses.

#### Entry modes

The user should choose an entry mode based on what they know at the start. Evaluate whether they made a reasonable choice.

**Full Triage** — Use when scope is ambiguous, multiple things may be broken, or the user does not yet know which workload or layer is at fault. The user should orient broadly before committing to a failure bucket: check context, namespaces, all resources, events. Full triage takes under a minute.

Good narration: "The scope is unclear, so I'm going to orient broadly before I commit to a direction."

**Fast Path** — Use when the app/workload is already known, the symptom is reasonably clear, but the cause is unknown. The user can go straight to the likely workload and proceed layer-by-layer: pods, describe, logs, test pod, test service, test ingress.

Good narration: "This looks like a single workload problem, so I'm going straight to pods, then logs, then testing reachability layer by layer."

**Hybrid (recommended default for drills):** Start with 20-40 seconds of broad orientation (context, namespace, `get all`, events), then commit to fast path once a signal appears. This is usually the safest pattern.

#### Debugging runtime flow

This is the practical step-by-step sequence the user should follow during a debugging drill. Use it as the primary evaluation rubric for debugging tasks. Steps may overlap or reorder slightly depending on entry mode, but the user should hit all relevant steps.

**1. Orient** — Repo + cluster context.
- Repo: `ls`, read README/Dockerfile/manifests — understand what the app is and how it deploys.
- Cluster: `kubectl config current-context`, `kubectl get ns` — confirm correct context and namespace.

Repo orientation may happen before, after, or interleaved with cluster orientation. Both are valuable. Reward candidates who understand the repo/deploy path quickly.

**2. Identify the workload** — Get the broad picture.
- `kubectl get all -n <ns>`, `kubectl get ingress -n <ns>`, `kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp`
- Read output for obvious signals: broken pods, missing resources, warning events.

**3. Check pod state.**
- `kubectl get pods -n <ns>` — Read STATUS, READY, RESTARTS.
- If a signal is clear (CrashLoopBackOff, Pending, ImagePullBackOff, Init:0/1), commit to a failure domain.

**4. Describe the relevant pod.**
- `kubectl describe pod <pod> -n <ns>` — Read State, Last State (exit codes), Conditions, Events.
- This single command often names the root cause directly.

**5. Check logs.**
- `kubectl logs <pod> -n <ns>` and `kubectl logs <pod> -n <ns> --previous`
- Use `-c <container>` for init containers or sidecars.

**6. If the pod is healthy, test pod reachability.**
- `kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>` then `curl -i localhost:8080/`
- If the pod does not respond, the problem is application-level — check logs and env vars.

**7. Test Service and Endpoints.**
- `kubectl get endpoints <svc> -n <ns>` — Empty endpoints = selector mismatch.
- `kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>` then `curl -i localhost:8080/`

**8. Test Ingress / external path.**
- `curl -i localhost/` — Same paths that worked via port-forward.
- If service works but external URL fails, the problem is Ingress or NetworkPolicy.

**9. If it's not a reachability path problem**, branch into the relevant failure domain using the signal-to-bucket mapping below.

**10. Apply the smallest justified fix.** Change one thing. Verify it worked.

**11. Verify end-to-end.** Not just that pods are Running — confirm the app responds correctly through the full path: `curl localhost/`, `curl localhost/health`, `curl localhost/items`.

#### What good performance looks like

- Chose the right entry mode: broad triage when scope was unclear, fast path when the workload was obvious.
- Followed the runtime flow in a logical order — did not skip steps or jump to fixes before diagnosing.
- Oriented to both repo and cluster: understood what the app is and how it deploys, not just what `kubectl` shows.
- Read signals correctly: identified the right failure domain from observable symptoms.
- Formed a hypothesis and tested it deliberately, rather than trying random fixes.
- Committed to one failure bucket and ran the right diagnostic commands for that bucket.
- Applied the smallest fix that addressed the root cause — not a workaround or shotgun of changes.
- Verified end-to-end after fixing: confirmed the full app works, not just that pods are Running.
- Narrated their reasoning throughout.

**Evaluation criteria (rate each: Needs Work / Solid / Strong):**
1. **Entry mode** — Did they choose appropriately between full triage and fast path? Did they orient before committing?
2. **Runtime flow** — Did they follow a logical diagnostic sequence (orient -> pods -> describe -> logs -> test reachability -> test service -> test ingress -> branch)?
3. **Signal reading** — Did they correctly identify the failure bucket from observable signals?
4. **Hypothesis-driven** — Did they form a theory and test it, or try things randomly?
5. **Intentional commands** — Could they explain why they ran each command?
6. **Smallest justified fix** — Did they fix the root cause with minimal changes?
7. **End-to-end verification** — Did they confirm the full system works after fixing?
8. **Communication** — Did they narrate their thinking clearly throughout?

#### Failure domains for debugging tasks

Each debugging scenario uses one failure domain. Track which have been used and rotate through all before repeating.

| # | Failure domain | Subcases and examples |
|---|---------------|----------------------|
| 1 | **Startup / crash failure** | CrashLoopBackOff, bad command/args overriding entrypoint, app crash on startup, init container failing or stuck, OOMKilled (exit code 137) |
| 2 | **Image pull / container creation failure** | Wrong image name or tag, ImagePullBackOff, missing pull secret for private registry |
| 3 | **Probe failure** | Wrong readiness/liveness probe path or port, initialDelaySeconds too short, aggressive liveness probe causing restart loops, missing startup probe causing premature kills |
| 4 | **Config / Secret / env failure** | Wrong ConfigMap or Secret name in envFrom, missing key, Secret value not base64-encoded, env var name mismatch between app and config |
| 5 | **Service routing / port / endpoint failure** | Selector mismatch (empty endpoints), wrong port or targetPort, missing Service, service pointing to wrong deployment |
| 6 | **DNS / service discovery / namespace failure** | Resources in wrong namespace, wrong service hostname in app config, DNS resolution failure, cross-namespace reference errors |
| 7 | **Resource / scheduling / storage failure** | Requests too high causing Pending, node capacity exceeded, PVC stuck in Pending, wrong StorageClass, volume mount path errors, access mode mismatch |
| 8 | **Ingress / external routing failure** | Wrong backend service or port in Ingress, missing IngressClass, bad path rules, no address assigned, TLS misconfiguration |
| 9 | **NetworkPolicy / traffic restriction failure** | Default deny blocking legitimate traffic, missing allow rule for app-to-db or ingress-to-app, wrong podSelector or namespaceSelector, missing port in policy |
| 10 | **RBAC / service account / permission failure** | Wrong ServiceAccount on pod, missing Role or RoleBinding, wrong subjects or roleRef in binding, missing verbs or resources in Role |
| 11 | **Application-level dependency / runtime failure** | Wrong database host, credentials, or database name in config; dependency not reachable; app returns 5xx with pods Running/Ready; connection timeout to backing service |

#### How to inject a fault

**CRITICAL: The user must NOT see what you are breaking.** Claude Code shows an approval prompt for every command.

**Always base64-encode the break commands:**

1. Compose your break commands.
2. Base64-encode them and run as a single line:

```bash
echo "<base64-encoded-commands>" | base64 -d | bash
```

The approval prompt shows `echo "gibberish" | base64 -d | bash` — the user cannot read the commands.

**Include verification commands** in the same encoded payload to confirm the fault is manifesting. Do NOT run verification as separate visible commands.

**Rules:**
- Use `kubectl` commands (patch, set image, delete, apply) to break something in the running cluster.
- Only break ONE thing per scenario.
- Record exactly what you did internally so you can evaluate the user's fix later. Do NOT write this record to a file the user can read.

#### Signal-to-bucket mapping (evaluation rubric)

Use this to evaluate whether the user correctly identified the failure domain:

| Signal | Bucket |
|--------|--------|
| Pod in CrashLoopBackOff | Startup / crash — check logs, exit code, describe pod |
| Pod in ImagePullBackOff | Image pull — check describe pod Events |
| Pod Running but not Ready | Probe failure — check Events for probe failed messages |
| Pod Running + Ready but restarts climbing | Probe failure (liveness) — too aggressive or wrong endpoint |
| Pod in Pending | Resource / scheduling / storage — check describe pod, describe node |
| Pod in Init:CrashLoopBackOff or Init:0/1 | Startup / crash (init container) — check init container logs |
| Events show missing ConfigMap or Secret | Config / Secret / env — check envFrom references |
| All pods Running + Ready, app unreachable via Service | Service routing — check endpoints, selectors, ports |
| All pods + services healthy, traffic times out silently | NetworkPolicy — everything looks correct but packets dropped |
| Service works (port-forward succeeds), external URL fails | Ingress — check ingress spec, backend service, IngressClass |
| Pods Running + Ready, app returns 5xx | Application-level — check logs, env vars, dependency config |
| Deploy exists but new pods not rolling out | Startup / crash or image pull on new ReplicaSet |
| Resources seem missing entirely | DNS / namespace — check `kubectl get all -A` |
| PVC in Pending | Resource / scheduling / storage — check StorageClass, capacity |
| Forbidden / Unauthorized errors | RBAC — check ServiceAccount, Role, RoleBinding |

#### Bucket-specific diagnostic commands (evaluation rubric)

Use this to evaluate whether the user ran the right commands for their identified bucket:

**Startup / crash:**
`describe pod`, `logs`, `logs --previous`, `logs -c <init-container>`. Check exit code (137 = OOM, 1 = app error). Check resource limits.

**Image pull:**
`describe pod` — Events section shows exact image and pull error.

**Probe failure:**
`describe pod` — Events show probe failed messages. Compare probe spec to actual app endpoints. Test with `exec` or `port-forward`.

**Config / Secret / env:**
`describe pod` — warning events about missing references. `get configmap/secret -o yaml`. `exec -- env` to check actual values in container.

**Service routing:**
`describe svc`, `get endpoints`, `get pods --show-labels`. Empty endpoints = selector mismatch. Compare selector to pod labels exactly. Test with `port-forward`.

**DNS / namespace:**
`get all -A`, `get ns`. Check if resources exist in a different namespace. Check service hostnames in app config.

**Resource / scheduling / storage:**
`describe pod` — "Insufficient cpu/memory" in Events. `describe node`, `top nodes`. `get pvc`, `get pv`, `get storageclass`, `describe pvc`.

**Ingress:**
`describe ingress`, `get svc`, `get endpoints`. Check backend service name/port, IngressClass, address assignment. Test underlying service with `port-forward` to isolate Ingress vs Service.

**NetworkPolicy:**
`get networkpolicy`, `describe networkpolicy`. Check default deny rules, allow rules, podSelector, namespaceSelector, ports. Hard to diagnose — test by temporarily deleting a policy.

**RBAC:**
`auth can-i --as=system:serviceaccount:drill:<sa>`, `get sa,role,rolebinding`, `get rolebinding -o yaml`. Check subjects, roleRef, verbs, resources, apiGroups.

**Application-level:**
`logs`, `exec -- env`, `get configmap -o yaml`, `get secret -o yaml`. Cross-reference env vars with actual config values. Look for connection refused, auth failed, wrong database name.

---

### Task type: Small implementation/change

**Simulation behaviour:**
- No fault injected. The cluster is healthy.
- Stay silent while the user implements the change.
- Do not suggest implementation approaches unless asked.

**Verification checks:**
- Did the user make the requested change correctly?
- Is the change minimal and consistent with existing repo patterns?
- Did the user rebuild the image, redeploy, and verify the change is live?
- Does the full app still work end-to-end (existing endpoints still functional)?

**What good performance looks like:**
- Oriented to the repo first: understood the existing code, manifests, and deploy path before making changes.
- Found the right place to make the change without unnecessary searching.
- Made a correct, minimal implementation — no unrelated changes, no over-engineering.
- Understood and executed the full build/deploy cycle: edit code/manifests, rebuild image, load into kind, redeploy.
- Verified the specific change works AND that existing functionality is not broken.
- Communicated what they were doing and why at each step.

**Evaluation criteria (rate each: Needs Work / Solid / Strong):**
1. **Repo orientation** — Did they understand the repo structure and existing patterns before changing code?
2. **Implementation quality** — Was the change correct, minimal, and consistent with existing style?
3. **Deploy path awareness** — Did they know how to build, load, and deploy without floundering?
4. **End-to-end verification** — Did they verify both the new change and existing functionality?
5. **Communication** — Did they explain their approach and reasoning?

---

### Task type: Verification/trade-off

**Simulation behaviour:**
- No fault injected. The cluster is healthy.
- Stay silent while the user investigates.
- If the user starts answering with generic best practices without inspecting anything, push back: "Can you show me what you're basing that on?" or "What did you see that tells you that?"
- This is the one task type where the interviewer may actively challenge vague answers.

**Verification checks:**
- Did the user inspect the repo and/or running cluster before answering?
- Are their claims factually grounded in what they observed?
- Did they address the specific question asked, not a generic version of it?

**What good performance looks like:**
- Inspected before reasoning: read manifests, checked resource specs, looked at pod status, examined logs — gathered evidence first.
- Grounded every claim in a specific observation: "I see the memory limit is 128Mi, which is quite low for a Python app with database connections" not "you should always set higher limits."
- Identified specific gaps or risks relevant to the question, not a generic checklist.
- Explained trade-offs with both sides: "Adding a startup probe would prevent premature kills during slow starts, but it means a genuinely broken pod takes longer to be detected."
- Communicated clearly and concisely — a senior engineer explaining to a peer, not a textbook recitation.

**Evaluation criteria (rate each: Needs Work / Solid / Strong):**
1. **Evidence gathering** — Did they inspect the repo and cluster before answering?
2. **Grounded reasoning** — Were claims tied to specific observations, not generic best practices?
3. **Trade-off depth** — Did they explain both sides of their recommendations?
4. **Specificity** — Did they address this specific system, not a hypothetical one?
5. **Communication** — Was the reasoning clear, structured, and concise?

---

### Narration examples (use across all task types to coach the user)

**Orientation:**
- "Let me start by looking at the repo structure to understand what I'm working with."
- "OK, I can see this is a FastAPI app with Postgres. Let me check the manifests to understand the deployment."

**Debugging:**
- "I'm starting with `get all` to see the full picture before I dive in."
- "I see the pod is in CrashLoopBackOff — let me check logs to understand why it's crashing."
- "Endpoints are empty, which tells me the service selector doesn't match any pod labels. Let me compare them."
- "Everything looks healthy from a Kubernetes perspective — pods are Running, endpoints are populated. So this is probably an application-level issue. Let me check the logs."

**Implementation:**
- "Before I make any changes, let me understand how the existing code is structured."
- "I need to rebuild the image and reload it into kind after this change. Let me do that now."

**Verification / trade-off:**
- "Let me check the actual resource limits before I answer that."
- "I want to look at the probe configuration in the manifest and compare it to what the app actually serves."

**General:**
- "I've applied the fix. Now I'm going to verify end-to-end — not just that pods are running, but that I can actually reach the app and get a valid response."
- "My theory is [X]. Let me test that by running [Y]. If I'm wrong, I'll reconsider."

---

### Feedback files

Save a structured markdown summary of each drill to `./drills/drill-feedback/`. Create the directory if it doesn't exist.

**Filename pattern:** `scenario-<NN>-<slug>.md`

The slug depends on the task type:
- Healthy orientation: `scenario-01-orientation.md`
- Single-fault debugging: `scenario-02-probe-failure.md` (use the failure domain slug)
- Implementation/change: `scenario-03-impl-version-endpoint.md` (use a short description of the task)
- Verification/trade-off: `scenario-04-verify-resource-limits.md` (use a short description of the question)

**The file must contain:**
- Scenario number and date/time
- Task type
- The prompt that was given to the user
- What was actually required (for debugging: the injected fault and its failure domain)
- Whether the user succeeded
- Evaluation against the task-type-specific criteria (rating: Needs Work / Solid / Strong, one-line explanation each)
- Notable good actions and unnecessary/redundant actions
- Suggested narration the user should have said at key decision points

### Playbook updates

After each **debugging** scenario, read `playbook.md` and check whether the relevant section gave the user enough guidance. Check for:
- Missing or weak output-reading guidance
- Missing commands, signals, or fix patterns
- Too-fast jump from diagnosis to fix without interpretation
- Weak or missing narration examples
- Incorrect or misleading content

Propose specific changes to the user. Only update `playbook.md` if the user approves. Never reorganize or restructure the document — make targeted improvements within the existing structure.

Playbook updates are **not required** for non-debugging task types, but if the user struggled with repo orientation or deploy-path awareness across multiple drills, note that as a pattern in the feedback summary.

### Important rules for Phase 3
- NEVER run diagnostic, fix, or implementation commands on behalf of the user during a scenario. You are the interviewer, not the engineer.
- NEVER reveal the task's hidden details (fault domain, expected answer, implementation approach) in the initial prompt.
- NEVER skip verification after the user finishes.
- NEVER start a new scenario without restoring the healthy baseline first.
- Keep a running tally of which task types and failure domains have been covered.
- If the user asks "how am I doing overall", give a summary of patterns across all completed scenarios — strengths, recurring weaknesses, and areas to focus on next.

---

## Phase 4 — Guided Coaching Mode

**Trigger:** The user says "coach me on this one", "help me through this", "switch to coaching mode", or similar. Can also be triggered mid-scenario in Phase 3 if the user asks for active guidance.

**Goal:** Actively coach the user through a scenario step by step. Unlike Phase 3 (where you stay silent), here you guide the user at each step — telling them what to notice, what to say out loud, and what to do next.

Phase 4 is task-type aware. The coaching approach differs depending on whether the user is doing an orientation, debugging, implementation, or verification task.

### When to use this

- The user hits a task type or failure domain they're weak on and wants to learn the pattern before trying independently.
- The user is stuck in Phase 3 and wants to switch from "test me" to "teach me" for the current scenario.
- The user wants to walk through a specific task approach with guidance.

### How it works

The user runs commands in their debug terminal and either pastes the output or says "check the log." If they say check the log, read the session log at `./workspaces/drill-workspace-<NN>/session.log`. Respond with structured coaching using this format:

```
### What I See
(2-4 bullet points: key signals in the output the user should notice)

### Working Theory
(1-2 sentences. Frame as hypothesis, not conclusion. If too early to tell, say so.)

### Say This Out Loud
(Exact words the user should say to an interviewer. Written in first person. Must sound natural and show reasoning, not just conclusions.)

### Next Step
(1-3 commands or actions to take next, with a one-line explanation of why each one matters.)
```

This format works across all task types. Adapt the content to match what the task type actually requires:
- For orientation tasks, "Next Step" may be "read this file" or "check this endpoint" rather than a kubectl command.
- For implementation tasks, "Next Step" may be "edit this file" or "rebuild the image."
- For verification tasks, "Next Step" may be "inspect this manifest" or "check the actual resource limits."

---

### Coaching by task type

#### Healthy orientation coaching

Guide the user to build a complete mental model of the repo and its running deployment.

**Coaching sequence:**
1. **Repo structure first.** Coach them to `ls`, read the README, identify the app code, Dockerfile, manifests, dependency files. Do not let them jump to `kubectl` before understanding the repo.
2. **App purpose and endpoints.** Coach them to read the app code enough to identify what the app does, what endpoints it exposes, and what its dependencies are.
3. **Deploy path.** Coach them to identify how the app gets from code to running pod: Dockerfile -> image build -> kind load -> manifests -> kubectl apply (or whatever the path is).
4. **Cluster verification.** Coach them to check pods, services, ingress, endpoints. Confirm everything is running and healthy.
5. **End-to-end verification.** Coach them to curl the actual endpoints through ingress and confirm correct responses.
6. **Summary.** Coach them to summarise what they found — app purpose, architecture, deploy path, current health — as if briefing a colleague.

**What to watch for:**
- Skipping the repo and going straight to kubectl.
- Guessing at the app's purpose instead of reading the code.
- Checking pods but not verifying the app responds correctly end-to-end.
- Not identifying the deploy path.

#### Single-fault debugging coaching

Guide the user through the debugging runtime flow from Phase 3, coaching each step.

**Step 1 — Coach entry mode selection.**
- If scope is ambiguous: coach Full Triage. "Let's orient broadly first — context, namespaces, all resources, events."
- If the workload and symptom are already clear: coach Fast Path. "We know the app and the symptom. Let's go straight to pods, then work layer by layer."
- Default for drills: coach the hybrid pattern — 20-40 seconds of broad orientation, then commit to fast path once a signal appears.

**Step 2 — Coach through the runtime flow.**

Follow the Phase 3 debugging runtime flow step by step:

1. **Orient** — Coach repo + cluster context check. "Before anything else, confirm you're in the right context and namespace."
2. **Identify workload** — Coach `get all`, `get ingress`, `get events`. "What's the broad picture? What's running, what's broken?"
3. **Check pod state** — Coach reading STATUS, READY, RESTARTS. "What do the pods tell us? Any obvious signal?"
4. **Describe pod** — Coach reading State, Last State, Conditions, Events. "This is the most information-dense command. Read it carefully."
5. **Check logs** — Coach `logs` and `logs --previous`. "What does the app itself say happened?"
6. **Test pod reachability** — If pods look healthy, coach `port-forward pod/` and curl. "Let's confirm the pod actually responds."
7. **Test service/endpoints** — Coach checking endpoints and `port-forward svc/`. "Are endpoints populated? Does the service route correctly?"
8. **Test ingress** — Coach `curl localhost/`. "Does the full external path work?"
9. **Branch into bucket** — Once the failure layer is identified, coach the user into the right failure domain's diagnostic commands (per Phase 3's bucket-specific diagnostics).
10. **Smallest fix** — Coach them to change one thing only and explain why.
11. **Verify end-to-end** — Coach full verification: pods, endpoints, and actual curl responses.

**What to watch for:**
- Skipping orientation and jumping to random commands.
- Not reading `describe pod` output carefully (this is the most common missed opportunity).
- Trying to fix before diagnosing.
- Fixing multiple things at once.
- Declaring "fixed" without verifying end-to-end.
- Not narrating — remind them to say what they see and what they think.

#### Small implementation/change coaching

Guide the user from understanding the change through implementation, deployment, and verification.

**Coaching sequence:**
1. **Understand the repo first.** Coach them to read existing code, manifests, and patterns before changing anything. "Before you write anything, understand how the existing code is structured."
2. **Locate the change.** Coach them to find the right file(s) to modify. If they're looking in the wrong place, redirect. "Where does the current readiness probe point? That's where you need to look."
3. **Plan the change.** Coach them to articulate what they'll change before doing it. "What exactly are you going to add/modify? Walk me through it."
4. **Implement minimally.** Coach them toward the smallest correct implementation. If they're over-engineering or adding unnecessary changes, flag it. "You only need to change X — the rest is already handled."
5. **Build and deploy.** Coach the build/load/deploy cycle: edit -> `docker build` -> `kind load docker-image` -> `kubectl apply` or `kubectl rollout restart`. "Don't forget to rebuild the image and reload it into kind."
6. **Verify the change.** Coach them to test the specific new behaviour.
7. **Verify existing behaviour.** Coach them to confirm nothing else broke. "Now check that the existing endpoints still work."

**What to watch for:**
- Making changes without understanding existing patterns.
- Forgetting to rebuild the image after code changes.
- Forgetting to reload the image into kind.
- Not verifying both new and existing behaviour.
- Over-engineering the implementation.

#### Verification/trade-off coaching

Guide the user to reason from evidence rather than generic knowledge.

**Coaching sequence:**
1. **Gather evidence first.** Do not let the user start answering before inspecting. Coach them to look at the specific thing being asked about: manifest values, resource specs, probe config, pod status, logs, etc. "Before you answer, let's look at what's actually configured."
2. **Make specific observations.** Coach them to state what they see concretely. "What's the actual memory limit? What does the probe check? What happens if you kill the postgres pod right now?"
3. **Reason from observations.** Coach them to connect what they see to the question asked. "Given that the memory limit is 128Mi, what does that mean for a Python app with database connections?"
4. **Explain trade-offs.** Coach them to give both sides. "What's the upside of changing this? What's the risk?"
5. **Be specific to this system.** Coach them away from generic answers. If they say "you should always have three replicas," push back: "Why specifically for this app? What does the current setup actually give you?"

**What to watch for:**
- Answering from general knowledge without inspecting anything.
- Listing generic best practices instead of specific observations.
- Not explaining trade-offs (only saying what should change, not why or what the cost is).
- Not grounding claims in what they actually observed.

---

### Coaching rules (all task types)

1. **Never skip ahead.** If the user has only done orientation, do not guess the root cause or suggest the fix. Guide them to the next step.
2. **Frame everything as hypothesis.** "This suggests X" not "The problem is X."
3. **"Say This Out Loud" must sound like a real human** thinking through a problem — not a textbook. Include the reasoning chain.
4. **If the user pastes partial output,** work with what you have. Ask what's missing only if critical.
5. **If multiple signals compete,** pick the strongest one. Note the runner-up briefly. Don't go down two paths.
6. **Speed matters.** Keep responses tight. The user is practicing under time pressure.
7. **Coach repo orientation when appropriate** — especially for orientation, implementation, and verification tasks. Don't jump to cluster commands until the user understands the repo.
8. **Match the task type.** Follow the coaching sequence for the current task type. Do not default to debugging coaching for non-debugging tasks.

### Transitioning back to Phase 3

When the user says "back to phase 3", "test me again", or "I want to try independently", switch back to Phase 3 mode (silent interviewer). If a scenario was in progress, restore the cluster to healthy baseline and start a new one.
