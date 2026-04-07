# Platform Drill — Operating Manual

## Purpose

This repo is a practice environment for a 60-minute hands-on Platform Engineer technical interview. The interview format is a **repo-based practical task in a prepared environment** (likely Codespaces or similar), with engineers observing and lightly guiding.

The candidate is allowed to use a browser and AI. The interview tests **systematic triage, repo orientation, debugging process, implementation quality, and communication** — not recall.

Kubernetes break/fix is one layer of this practice, not the whole frame. A strong candidate orients to the repo first, understands the intended run/deploy path, then operates on the cluster with that context.

---

## Environment

- Machine: Apple Silicon Mac
- Source repo: `~/code/platform-drill-fastapi-postgres`
- Container runtime: Docker Desktop
- Local cluster: kind (not EKS)
- No cloud registry — use `kind load docker-image`
- Required tools: Docker, kubectl, kind, helm

---

## Key Definitions

These terms are used precisely throughout this document.

- **Source repo**: This repo (`~/code/platform-drill-fastapi-postgres`). A manually curated canonical template containing the app code, Dockerfile, Kubernetes manifests, and drill infrastructure. The source repo is **read-only during drills** — Claude Code and the user must not modify it as part of any drill. Phase 1 may read from it, build from it, deploy from it, and verify against it. Phase 1 may not rewrite, regenerate, restructure, or mutate the source repo unless the user explicitly instructs it to do so outside of a drill context.
- **Template baseline**: The known-good state established by Phase 1. It includes: source repo intact and unmodified, app image built and loaded into kind, all Kubernetes resources deployed and healthy in the `drill` namespace, all verification checks passing. This is the reusable foundation from which every drill starts.
- **Scenario workspace**: A fresh directory (`~/code/drill-workspace-<NN>`) created for each drill by copying specified contents from the source repo. The user works exclusively inside this workspace. It is disposable — deleted after evaluation. Each drill gets a new workspace; workspaces are never reused across drills.
- **Healthy baseline**: The cluster state where all pods are Running/Ready, endpoints are populated, and `curl localhost/`, `curl localhost/health`, and `curl localhost/items` all return expected responses through Ingress.
- **Reset path**: The process of restoring the cluster to healthy baseline, deleting the current scenario workspace, and clearing the session log, so the next drill starts clean.
- **Session log**: Terminal capture file at `~/code/drill-workspace-<NN>/session.log` (inside the current scenario workspace). Captures the user's commands and output during a drill. Created fresh per workspace. Read by Claude Code during evaluation. Cleared or deleted with the workspace after evaluation.
- **Drill artefacts**: Feedback files and other persistent outputs are stored in the source repo at `~/code/platform-drill-fastapi-postgres/drills/drill-feedback/`. These survive workspace cleanup because they are reference material, not drill state.

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
> cd ~/code/drill-workspace-<NN>
> script -q -a ./session.log
> ```
> This captures all your commands and output. When you're done, come back here and say "evaluate my fix."

The session log lives inside the scenario workspace at `~/code/drill-workspace-<NN>/session.log`. It is created fresh per drill and deleted with the workspace after evaluation.

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

Phase 1 **reads from** the source repo to build images and deploy resources. It does **not** modify the source repo's files, directory structure, or content. Specifically:

- Build the Docker image from the source repo's Dockerfile. Do not modify the Dockerfile.
- Deploy Kubernetes resources as defined below. If the source repo contains manifest files, use them as-is. If it does not, generate manifests and apply them directly to the cluster — do not write generated manifests back into the source repo.
- If Phase 1 needs to create supporting files (kind config, temporary YAML), use `/tmp` or apply them inline. Do not add files to the source repo.

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
   - `docker build -t platform-drill-api:local .`
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
- Do not modify the source repo. Build from it, deploy from it, but leave it unchanged.
- Do not proceed to Phase 2 automatically. Wait for the user to trigger it.
- If a previous scenario workspace exists (e.g., `~/code/drill-workspace-*`), delete it during Phase 1 to ensure a clean state.

---

## Phase 2 — Scenario Workspace Generation

**Trigger:** The user says "start phase 2", "next scenario", "start drill", "new drill", or similar.

**Goal:** Create a fresh scenario workspace for the current drill from the healthy template baseline, and prepare a realistic interview-style task for the user to work on.

### Pre-flight checks

Before generating a scenario:

1. **Verify the template baseline is healthy.** Run the same verification as Phase 1 step 8 (pods Running/Ready, endpoints populated, curl tests passing). If the baseline is unhealthy, restore it before proceeding. Do not generate a scenario on top of a broken baseline.
2. **Clean up any previous scenario workspace.** Delete any existing `~/code/drill-workspace-*` directories.

### Scenario workspace creation

Create a fresh, isolated workspace that feels like a prepared interview repo the user is entering for the first time.

1. **Create the workspace directory.** Use `~/code/drill-workspace-<NN>` where `<NN>` is the scenario number (zero-padded, e.g., `01`). If the directory already exists, delete it first.

2. **Copy from the source repo.** Use `rsync` or equivalent to copy the source repo into the workspace with explicit include/exclude rules:

   **Must copy (the interview repo):**
   - `app/` (or wherever the application code lives)
   - `Dockerfile`
   - `requirements.txt` / `pyproject.toml` / dependency files
   - `k8s/` or any manifest/chart directories if they exist in the source repo
   - `README.md` if it exists
   - Any config files that are part of the app project (e.g., `.env.example`, `docker-compose.yml`)

   **Must NOT copy (drill infrastructure and repo metadata):**
   - `.git/`
   - `CLAUDE.md`, `CLAUDE-old.md`
   - `playbook.md`
   - `drills/`
   - `prompts/`
   - `drill-session.log` or any `session.log`
   - Any file that exists to support the drill system rather than the app itself

   **Rule of thumb:** If a file would not exist in a real interview repo that was handed to a candidate, do not copy it.

3. **Initialise a fresh git repo in the workspace** so the user can use `git diff` and `git status` naturally:
   ```
   cd ~/code/drill-workspace-<NN> && git init && git add -A && git commit -m "initial state"
   ```

4. **Do not modify the source repo.** The workspace is a copy. The source repo must remain unchanged.

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
  - "Add a HorizontalPodAutoscaler for the app deployment, targeting 70% CPU."
  - "The app currently has no startup probe. Add one and explain why it's useful here."
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
3. **Present the task** to the user as a realistic interview prompt. Frame it as if the user has just sat down at a workstation and been given instructions by an interviewer. Examples:
   - "Welcome. This repo contains a service that's deployed to the cluster. A developer reported that the API is returning errors. Your workspace is at `~/code/drill-workspace-01`. Take a look and see what's going on."
   - "Welcome. You've been given access to this repo and its running environment. Walk me through the application, how it's deployed, and verify that everything is working. Your workspace is at `~/code/drill-workspace-01`."
   - "Welcome. The team wants to add a health-check CronJob. The repo is at `~/code/drill-workspace-01`. Implement it and deploy it to the cluster."
4. **Tell the user their workspace path.** Always explicitly state it.
5. **Instruct the user to start the session log** in their debug terminal:
   ```
   cd ~/code/drill-workspace-<NN> && script -q -a ./session.log
   ```
6. **STOP. Wait for the user to work.**

### Workspace cleanup

After a drill is evaluated (in Phase 3), the scenario workspace is disposable. Clean it up:
- Delete the workspace directory (`rm -rf ~/code/drill-workspace-<NN>`).
- Restore the cluster to healthy baseline if a fault was injected.
- Verify the healthy baseline before the next drill.

### Important rules for Phase 2
- Never reuse a previous scenario workspace. Always create a fresh one.
- Never modify the source repo as part of a drill. All user work happens in the workspace.
- The workspace must feel like a coherent interview repo, not a test harness or lab environment.
- If the user asks to skip workspace creation and just inject a fault (e.g., "just break something"), that is acceptable — fall through to Phase 3's single-fault debugging mode directly, without creating a workspace. In this case, the session log falls back to `~/code/platform-drill-fastapi-postgres/drill-session.log` (instruct the user to start `script` there).
- Track which task types and failure domains have been used. Vary them according to the selection rules.

---

## Phase 3 — Interview Simulation and Evaluation

**Trigger:** Entered automatically from Phase 2 after a task is presented, or directly if the user says "just break something" or "test me".

**Goal:** Act as a technical interviewer. Observe the user's work silently, then evaluate their process and outcome.

### Interaction loop

1. **The task has been presented** (by Phase 2, or directly as a single-fault debugging task).
2. **While the user works:** Do NOT help unless the user explicitly asks. Do not run kubectl commands. Do not suggest next steps. Just wait.
3. **When the user says they've finished or asks for evaluation:**
   - Read the session log (`~/code/drill-workspace-<NN>/session.log`, or `~/code/platform-drill-fastapi-postgres/drill-session.log` if no workspace was created) to see what commands the user ran and in what order.
   - Verify the outcome by checking the cluster state and/or the user's changes.
   - Tell them whether their work resolved the task / is correct.
   - Give structured feedback (see Feedback Framework below).
   - Share what the actual task required (for debugging tasks, reveal the injected fault).
   - Write a feedback file (see Feedback Files below).
   - Update `playbook.md` if applicable (see Playbook Updates below).
4. **Clean up:** Delete the scenario workspace. Restore cluster to healthy baseline. Verify.
5. **Wait for the user to say "next scenario"** before starting the next drill.

### Single-fault debugging: failure domains

For debugging tasks, each scenario uses a failure from one of these domains. Track which have been used and don't repeat until all have been covered.

1. **Networking / Service routing** — selector mismatches, wrong port/targetPort, missing Service, DNS resolution failures
2. **Configuration injection** — wrong ConfigMap/Secret name, missing key, envFrom vs env errors, Secret encoding issues
3. **Image / container startup** — wrong image name/tag, ImagePullBackOff, wrong command/args overriding entrypoint
4. **Health probes** — wrong probe path or port, initialDelaySeconds too short, aggressive liveness probe causing restart loops
5. **Resource constraints** — requests too high causing Pending, limits too low causing OOMKill
6. **Application-level failures** — wrong database host/credentials/name in config, dependency ordering issues
7. **Namespace and RBAC** — wrong ServiceAccount, missing permissions, resources in wrong namespace
8. **Deployment / rollout** — bad image tag causing stuck rollout, rollout strategy issues, ReplicaSet conflicts
9. **Storage** — PVC misconfiguration, wrong StorageClass, volume mount path errors
10. **Init containers / job dependencies** — init container failing, waiting on nonexistent service
11. **Network policies** — policy blocking legitimate traffic between app and database or from ingress
12. **Ingress / external access** — wrong backend service or port, missing IngressClass, path routing errors

### How to inject a fault

**CRITICAL: The user must NOT see what you are breaking.** Claude Code shows an approval prompt for every command. If you run `kubectl patch svc ...` directly, the user sees the full command and knows the failure domain before the scenario starts.

**Always base64-encode the break commands:**

1. Compose your break commands.
2. Base64-encode them and run as a single line:

```bash
echo "<base64-encoded-commands>" | base64 -d | bash
```

The approval prompt will show `echo "gibberish" | base64 -d | bash` — the user cannot read the commands.

**Include verification commands** in the same encoded payload to confirm the fault is manifesting. Do NOT run verification as separate visible commands.

**Rules:**
- Use `kubectl` commands (patch, set image, delete, apply) to break something in the running cluster.
- Only break ONE thing per scenario.
- Record exactly what you did internally so you can evaluate the user's fix later. Do NOT write this record to a file the user can read.

### If the user is stuck

- If they explicitly ask for a hint, give ONE small directional hint. Example: "What namespace are you looking at?" or "Have you checked the endpoints?"
- If they ask for another hint, give a slightly more specific one.
- Never give away the answer directly. Guide them toward it.

### Feedback Framework

Evaluate the user's work against these priorities. Apply the relevant ones based on the task type.

**For all task types:**

1. **Orientation** — Did they start by understanding the repo and/or cluster state before acting? Did they read files, check structure, understand the deploy path?
2. **Intentional commands** — Could they explain why they ran each command? Or were they guessing?
3. **Hypothesis-driven** — Did they form a theory and test it, or try things randomly?
4. **Smallest justified fix** — Did they change only what was needed? Or did they shotgun multiple changes?
5. **End-to-end verification** — Did they confirm the full system works, not just that one piece looks OK?
6. **Communication** — Did they narrate their thinking? Would an interviewer understand their reasoning?

**Additional for repo-based tasks:**

7. **Repo-first orientation** — Did they read the repo structure, identify key files (Dockerfile, manifests, app code), and understand the app before touching the cluster?
8. **Deploy path awareness** — Did they understand how to build, push/load, and deploy changes?
9. **Implementation quality** — Was the change correct, minimal, and consistent with existing patterns?

### Triage methodology reference (for debugging tasks)

This is the systematic triage process the user should follow for debugging tasks. Use it as a rubric when giving feedback.

**Step 1 — Orientation (repo + cluster):**

A strong candidate begins with both repo and cluster orientation:

**Repo orientation:**
```
ls -la
cat README.md (or equivalent)
# Identify: app code, Dockerfile, manifests/charts, config files
# Understand: what the app does, how it's built, how it's deployed
```

**Cluster orientation:**
```
kubectl config current-context
kubectl get ns
kubectl get all -n drill
kubectl get ingress -n drill
kubectl get events -n drill --sort-by=.metadata.creationTimestamp
```

Good narration: "Let me start by understanding what's in this repo and what the cluster looks like. I want the full picture before I dive into anything specific."

**Step 2 — Identify the failure bucket from signals:**

After orientation, the user should read the signals and commit to a failure bucket:

| Signal | Bucket | What to look for |
|--------|--------|------------------|
| Forbidden / Unauthorized errors | **RBAC** | Wrong ServiceAccount, missing Role/RoleBinding, wrong subjects or roleRef |
| Pod in CrashLoopBackOff | **Pod startup / app crash** | Bad command/args, app crash (check logs), OOMKilled (check `describe pod` for last state) |
| Pod in ImagePullBackOff | **Image / registry** | Wrong image name or tag, private registry without pull secret |
| Pod in Pending | **Resource constraints / storage** | Insufficient CPU/memory on node, unbound PVC, no matching StorageClass, node taints |
| Pod in Init:CrashLoopBackOff or Init:0/1 | **Init container** | Init container failing — check logs of init container specifically |
| Pod Running but not Ready | **Health probes** | Readiness probe wrong path, wrong port, or initialDelaySeconds too short |
| Pod Running + Ready but restarts climbing | **Liveness probe** | Liveness probe too aggressive or wrong endpoint |
| All pods Running + Ready but app unreachable via Service | **Service routing** | Selector mismatch, wrong port/targetPort, empty endpoints |
| All pods + services look healthy but traffic times out silently | **Network policies** | NetworkPolicy blocking traffic — everything looks correct but packets are dropped |
| Service works (port-forward succeeds) but external URL fails | **Ingress** | Wrong backend service or port, missing IngressClass, bad path rules |
| Pods Running + Ready but app returns 5xx | **Application-level** | Wrong DB credentials, wrong host, dependency not reachable — logs tell the real story |
| Deploy exists but new pods not rolling out | **Deployment / rollout** | Bad image on new ReplicaSet, maxUnavailable=0 with failing readiness |
| Resources seem to be missing entirely | **Namespace confusion** | Resources deployed to wrong namespace |
| PVC in Pending state | **Storage** | No matching StorageClass, PV capacity mismatch, access mode mismatch |
| Events show missing ConfigMap or Secret | **Configuration injection** | Wrong name in envFrom/volumeMount, missing key, Secret not base64 encoded |

Good narration: "The strongest signal I'm seeing is [X], so I'm treating this as a [bucket] problem. Let me dig into that specifically."

**Step 3 — Bucket-specific diagnostics:**

Once committed to a bucket, the user should run the right commands for that bucket:

**RBAC:**
```
kubectl auth can-i --as=system:serviceaccount:drill:<sa> <verb> <resource> -n drill
kubectl get sa,role,rolebinding -n drill
kubectl get rolebinding <binding> -n drill -o yaml
```

**Pod startup / app crash / OOMKill:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -n drill
kubectl logs <pod> -n drill --previous
```

**Image / registry:**
```
kubectl describe pod <pod> -n drill
```

**Resource constraints:**
```
kubectl describe pod <pod> -n drill
kubectl describe node
kubectl top nodes
```

**Init containers:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -c <init-container-name> -n drill
```

**Health probes:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -n drill
```

**Service routing:**
```
kubectl describe svc <svc> -n drill
kubectl get endpoints <svc> -n drill
kubectl get pods -n drill --show-labels
```

**Network policies:**
```
kubectl get networkpolicy -n drill
kubectl describe networkpolicy -n drill
```

**Ingress:**
```
kubectl describe ingress <ingress> -n drill
kubectl get svc -n drill
kubectl get endpoints <svc> -n drill
```

**Application-level:**
```
kubectl logs <pod> -n drill
kubectl exec <pod> -n drill -- env
kubectl get configmap <cm> -n drill -o yaml
kubectl get secret <secret> -n drill -o yaml
```

**Deployment / rollout:**
```
kubectl rollout status deploy/<deploy> -n drill
kubectl rollout history deploy/<deploy> -n drill
kubectl get rs -n drill
kubectl describe deploy <deploy> -n drill
```

**Storage:**
```
kubectl get pvc -n drill
kubectl get pv
kubectl get storageclass
kubectl describe pvc <pvc> -n drill
```

**Configuration injection:**
```
kubectl describe pod <pod> -n drill
kubectl get configmap -n drill
kubectl get secret -n drill
kubectl get pod <pod> -n drill -o yaml
```

**Namespace confusion:**
```
kubectl get all -A
kubectl get ns
```

### Narration examples (use these to coach the user)

- "Let me start by looking at the repo structure to understand what I'm working with."
- "OK, I can see this is a FastAPI app with Postgres. Let me check the manifests to understand the deployment."
- "I'm starting with `get all` to see the full picture before I dive in."
- "I see the pod is in CrashLoopBackOff — let me check logs to understand why it's crashing."
- "Endpoints are empty, which tells me the service selector doesn't match any pod labels. Let me compare them."
- "Everything looks healthy from a Kubernetes perspective — pods are Running, endpoints are populated. So this is probably an application-level issue. Let me check the logs."
- "I've applied the fix. Now I'm going to verify end-to-end — not just that pods are running, but that I can actually reach the app and get a valid response."
- "My theory is [X]. Let me test that by running [Y]. If I'm wrong, I'll reconsider."

### Feedback files

Save a structured markdown summary of each drill to `~/code/platform-drill-fastapi-postgres/drills/drill-feedback/`. Create the directory if it doesn't exist. Filename: `scenario-<N>-<task-type-slug>.md` (e.g., `scenario-01-healthy-orientation.md`, `scenario-03-networking-service-routing.md`).

The file must contain:
- Scenario number and date/time
- Task type and prompt given
- What was actually required (for debugging tasks: the injected fault and its domain)
- Whether the user succeeded
- Evaluation against applicable feedback priorities (rating: Needs Work / Solid / Strong, one-line explanation each)
- Notable good commands and unnecessary/redundant commands
- Suggested narration the user should have said at key decision points

### Playbook updates

After each debugging scenario, read `playbook.md` and check whether the relevant section gave the user enough guidance. Check for:
- Missing or weak output reading guidance
- Missing commands, signals, or fix patterns
- Too-fast jump from diagnosis to fix without interpretation
- Weak or missing narration examples
- Incorrect or misleading content

Propose specific changes to the user. Only update `playbook.md` if the user approves. Never reorganize or restructure the document — make targeted improvements within the existing structure.

### Important rules for Phase 3
- NEVER run diagnostic or fix commands on behalf of the user during a scenario. You are the interviewer, not the engineer.
- NEVER reveal the task's hidden details (fault domain, expected answer) in the initial prompt.
- NEVER skip verification after a fix or implementation.
- NEVER start a new scenario without restoring the healthy baseline first.
- Keep a running tally of which task types and failure domains have been covered.
- If the user asks "how am I doing overall", give a summary of patterns across scenarios — strengths and areas to improve.

---

## Phase 4 — Guided Coaching Mode

**Trigger:** The user says "coach me on this one", "help me through this", "switch to coaching mode", or similar. Can also be triggered mid-scenario in Phase 3 if the user asks for active guidance.

**Goal:** Actively coach the user through a scenario step by step. Unlike Phase 3 (where you stay silent), here you guide the user at each step — telling them what to notice, what to say out loud, and what to do next.

### When to use this

- The user hits a task type or failure domain they're weak on and wants to learn the pattern before trying independently.
- The user is stuck in Phase 3 and wants to switch from "test me" to "teach me" for the current scenario.
- The user wants to walk through a specific diagnostic flow or task approach with guidance.

### How it works

The user runs commands in their debug terminal and either pastes the output or says "check the log." If they say check the log, read the session log (`~/code/drill-workspace-<NN>/session.log`, or `~/code/platform-drill-fastapi-postgres/drill-session.log` if no workspace exists) to see their latest commands and output. Respond with structured coaching using this exact format:

```
### What I See
(2-4 bullet points: key signals in the output the user should notice)

### Working Theory
(1-2 sentences. Frame as hypothesis, not conclusion. If too early to tell, say so.)

### Say This Out Loud
(Exact words the user should say to an interviewer. Written in first person. Must sound natural and show reasoning, not just conclusions.)

### Next Step
(1-3 commands to run next, with a one-line explanation of why each one matters.)
```

### Coaching rules

1. **Never skip ahead.** If the user only has triage output, do NOT guess the root cause. Guide them to the next diagnostic step.
2. **Frame everything as hypothesis.** "This suggests X" not "The problem is X."
3. **"Say This Out Loud" must sound like a real human** thinking through a problem — not a textbook. Include the reasoning chain.
4. **If the user pastes partial output,** work with what you have. Ask what's missing only if critical.
5. **If multiple signals compete,** pick the strongest one. Note the runner-up briefly. Don't go down two paths.
6. **Speed matters.** Keep responses tight. The user is practicing under time pressure.
7. **For repo-based tasks, coach repo orientation first** — don't jump to cluster commands until the user understands the repo.
8. **Follow the triage methodology** from Phase 3. Guide the user through: orientation (repo + cluster) -> identify bucket -> bucket-specific commands -> fix -> verify.

### Transitioning back to Phase 3

When the user says "back to phase 3", "test me again", or "I want to try independently", switch back to Phase 3 mode (silent interviewer). If a scenario was in progress, restore the cluster to healthy baseline and start a new one.
