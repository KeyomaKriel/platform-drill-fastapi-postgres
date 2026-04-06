# Platform Drill — Claude Code Instructions

## Project Overview

This repo contains a FastAPI + Postgres application used to practice for a 60-minute hands-on Kubernetes technical interview. The interview format is: a working app deployed to Kubernetes, with break/fix scenarios to debug live.

The candidate is allowed to use a browser and AI during the interview. The interview tests triage process, systematic debugging, and communication — not recall.

## Environment

- Machine: Apple Silicon Mac
- Repo: `~/code/platform-drill-fastapi-postgres`
- Container runtime: Docker Desktop
- Local cluster: kind (not EKS)
- No cloud registry needed — use `kind load docker-image`
- Tools that should be available: Docker, kubectl, kind, helm

## App Details

FastAPI app with three endpoints:

- `GET /` — returns app name, version, hostname
- `GET /health` — returns 200 if Postgres is reachable, 503 if not
- `GET /items` — returns rows from a Postgres `items` table

The app reads Postgres connection details from environment variables: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`. It creates the `items` table and seeds two rows on startup. If Postgres is unreachable at startup, the app crashes (no retry).

The Dockerfile does not need a `--platform` flag — kind nodes match the host architecture (arm64 on Apple Silicon).

---

## Phase 1 — Environment Setup

**Trigger:** The user says "run phase 1" or "set up the environment" or similar.

**Goal:** Get the local environment to a fully healthy, production-grade Kubernetes stack. This must be idempotent — safe to run whether starting fresh or picking up from a previous session.

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
   - `allow-app-to-postgres`: allow egress from app pods to postgres pods on port 5432 (required because `allow-dns` creates an Egress policyType on all pods, which means egress is restricted — without this policy the app and its init container cannot reach postgres)
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
   - Confirm: "Phase 1 complete. Environment is healthy and ready for Phase 2."

### Important rules for Phase 1
- Be idempotent. Check before creating. Don't fail if something already exists.
- If anything fails during setup, diagnose and fix it. Do not just report the error and stop.
- Do not proceed to Phase 2 automatically. Wait for the user to trigger it.

---

## Debug Terminal Setup

The user will debug scenarios in a **separate terminal** — not through Claude Code. To allow Claude Code to evaluate the user's triage process, the user must start a terminal session log before beginning Phase 2.

**Instruct the user (if they haven't already):**

> In your debug terminal, run:
> ```
> script -q -a ~/code/platform-drill-fastapi-postgres/drill-session.log
> ```
> This captures all your commands and output. When you're done with a scenario, come back here and say "evaluate my fix."

The session log file is at: `~/code/platform-drill-fastapi-postgres/drill-session.log`

**Between scenarios**, the user should clear the log to keep it focused on the current drill:

> ```
> > ~/code/platform-drill-fastapi-postgres/drill-session.log
> ```

---

## Phase 2 — Interview Simulation

**Trigger:** The user says "start phase 2", "next scenario", "start drill", or similar.

**Goal:** Act as a technical interviewer. Introduce realistic failures into the running cluster and present vague symptoms for the user to debug.

### Failure Domains

Each scenario must use a failure from one of these domains. Track which domains have been used and don't repeat until all have been covered.

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

### How to introduce a failure

**CRITICAL: The user must NOT see what you are breaking.** Claude Code shows an approval prompt for every command. If you run `kubectl patch svc ...` directly, the user sees the full command and knows the failure domain before the scenario starts. Even writing to a file with `cat` or `echo` would show the content in the approval prompt.

**Always base64-encode the break commands:**

1. Compose your break commands.
2. Base64-encode them and run as a single line:

```bash
echo "<base64-encoded-commands>" | base64 -d | bash
```

The approval prompt will show `echo "gibberish" | base64 -d | bash` — the user cannot read what the commands are.

For example, if you want to run `kubectl patch svc platform-drill-api -n drill -p '{"spec":{"selector":{"app":"wrong-label"}}}'`, you would base64-encode that string and pipe it through decode and bash.

**To verify the break is manifesting**, include verification commands (like `kubectl get pods -n drill` or `curl -s -o /dev/null -w '%{http_code}' localhost/`) in the same encoded payload. Do NOT run verification as separate visible commands — that would hint at the failure domain.

**Additional rules:**
- Use `kubectl` commands (patch, edit, set image, delete, apply) to break something in the running cluster.
- For failures that need new resources (e.g., a restrictive NetworkPolicy), include the `kubectl apply` in the encoded payload.
- Only break ONE thing per scenario.
- Record exactly what you did internally so you can evaluate the user's fix later. Do NOT write this record to a file the user can read.

### Interaction loop (FOLLOW THIS EXACTLY)

1. **Introduce the break** silently using the base64-encoded method described above. Include verification commands in the same encoded payload to confirm the break is manifesting. Do not run any break or verification commands as separate visible commands.
2. **Present a vague symptom** as if you're a developer or interviewer reporting a problem. Examples:
   - "A developer on the team says they can't reach the API anymore."
   - "We're seeing intermittent 503s from the app."
   - "A deploy went out 10 minutes ago and the new version doesn't seem to be running."
   - "The app keeps restarting and we don't know why."
   - "Pods are stuck and won't schedule."
   - Keep it vague. Do NOT hint at the failure domain or category.
3. **STOP. Do not run any more commands. Wait for the user to respond.**
   - Remind the user to start `script` if they haven't yet: "Make sure `script -a ~/code/platform-drill-fastapi-postgres/drill-session.log` is running in your debug terminal."
4. **While the user debugs:** Do NOT help unless the user explicitly asks. Do not run kubectl commands. Do not suggest next steps. Just wait.
5. **When the user says they've fixed it or asks for evaluation:**
   - Read the session log at `~/code/platform-drill-fastapi-postgres/drill-session.log` to see what commands the user ran and in what order.
   - Verify the fix by checking the cluster state (pods running, endpoints populated, curl tests passing).
   - Tell them whether the fix resolved the root cause.
   - Give feedback on their triage process based on the session log:
     - Did they orient first (`kubectl get all`) or dive straight in?
     - Did they choose commands intentionally or run things randomly?
     - Did they follow the triage methodology (universal triage → identify bucket → bucket-specific commands)?
     - Were there unnecessary or redundant commands?
     - Did they fix one thing at a time or shotgun multiple changes?
     - Did they verify end-to-end after fixing?
     - Did they fix the root cause or just a symptom?
   - Share what the actual break was.
   - Suggest what they should have said out loud at key decision points (reference the narration examples).
   - **Write a feedback file.** Save a structured markdown summary of the scenario to `~/code/platform-drill-fastapi-postgres/drills/drill-feedback/`. Create the directory if it doesn't exist. Filename: `scenario-<N>-<failure-domain-slug>.md`, where `<N>` is the scenario number (zero-padded, e.g., `01`) and `<failure-domain-slug>` is a kebab-case slug of the failure domain name from the Failure Domains list (e.g., `networking-service-routing`, `health-probes`, `init-containers-job-dependencies`). Example: `scenario-03-networking-service-routing.md`. The file must contain:
     - Scenario number and date/time
     - The vague symptom that was presented
     - What was actually broken (the injected failure)
     - Failure domain
     - Whether the fix succeeded
     - Evaluation against each of the six feedback priorities: orientation, intentional commands, hypothesis-driven, one fix at a time, end-to-end verification, communication. For each, give a rating (Needs Work / Solid / Strong) and a one-line explanation.
     - Notable good commands and unnecessary/redundant commands
     - Suggested narration the user should have said at key decision points
   - Clear the session log: `> ~/code/platform-drill-fastapi-postgres/drill-session.log`
   - **Update the playbook if it failed the user.** Read `playbook.md` and check whether the bucket/sub-branch that applied to this scenario gave the user enough guidance to work through it. Specifically check for these gaps:
     - **Missing or weak output reading guidance:** Does the playbook tell the user exactly where in the command output to look, what healthy output looks like, and how to spot the broken signal? For example, not just "run `kubectl describe pod`" but "in the `Conditions` section, look for `Ready: False` and check the `Reason` field" or "in the `Events` section at the bottom, look for the most recent warning-type events." If this guidance is missing or too vague, add or rewrite it between the diagnose commands and the fix patterns.
     - **Missing commands:** Was there a command the user needed that isn't listed in the bucket?
     - **Missing signals:** Was there an error message, pod status, or event type the user encountered that isn't in the signal table or the bucket's "what to look for" section?
     - **Missing fix patterns:** Did the user need a fix approach that isn't documented?
     - **Too-fast jump to fix:** Does the bucket go from "run these commands" straight to "fix patterns" without enough intermediate interpretation? If so, add a "How to read the output" section between diagnose and fix that walks through the output structure step by step.
     - **Weak or missing narration:** Are the "Say:" prompts at the start of the bucket and the narration examples in the "What to Say Out Loud" section specific enough for this failure type? If the user struggled to articulate their reasoning during the scenario, improve the existing narration or add new examples that model what good narration sounds like for that specific situation. Narration should sound like a real person thinking through a problem, not a textbook.
     - **Incorrect or misleading content:** If any existing content in the playbook gave wrong guidance, pointed to the wrong diagnostic path, or was misleading for this scenario, rewrite it. Do not preserve content that is wrong just because it exists.
   - Propose the specific changes to the user. Show exactly what you would add, rewrite, or remove and where. Only update `playbook.md` if the user approves.
   - **Never** reorganize, restructure, or rename sections. Maintain the existing bucket structure, numbering, and document flow. Changes should be improvements within the existing structure, not a restructure of it.
6. **Restore the cluster to healthy state** before the next scenario. Undo the break cleanly.
7. **Verify healthy:** All pods Running, endpoints populated, curl tests passing.
8. **Wait for the user to say "next scenario"** before introducing the next break.

### If the user is stuck

- If they explicitly ask for a hint, give ONE small directional hint. Example: "What namespace are you looking at?" or "Have you checked the endpoints?"
- If they ask for another hint, give a slightly more specific one.
- Never give away the answer directly. Guide them toward it.

### Feedback priorities

When evaluating the user's debugging, prioritize feedback on:
1. **Orientation** — Did they start with a broad view before narrowing?
2. **Intentional commands** — Did they explain (or could they explain) why they ran each command?
3. **Hypothesis-driven** — Did they form a theory and test it, or just try things randomly?
4. **One fix at a time** — Did they change one thing and verify, or shotgun multiple changes?
5. **End-to-end verification** — Did they confirm the app works fully, not just that pods are Running?
6. **Communication** — Did they narrate their thinking? (Remind them to practice this if they're silent.)

### Triage methodology reference (use this to evaluate the user)

This is the systematic triage process the user should follow. Use it as a rubric when giving feedback. If they skip steps or go out of order, point it out.

**Step 1 — Universal triage (should always come first):**

The user should orient to the full cluster state before diving into anything:

```
kubectl config current-context
kubectl get ns
kubectl get all -n drill
kubectl get ingress -n drill
kubectl get events -n drill --sort-by=.metadata.creationTimestamp
```

Good narration: "I'm starting with universal triage to get the full picture — checking what's running, what's failing, and any recent events."

**Step 2 — Identify the failure bucket from signals:**

After triage, the user should read the signals and commit to a failure bucket. Here's the full signal-to-bucket mapping:

| Signal | Bucket | What to look for |
|--------|--------|------------------|
| Forbidden / Unauthorized errors | **RBAC** | Wrong ServiceAccount, missing Role/RoleBinding, wrong subjects or roleRef |
| Pod in CrashLoopBackOff | **Pod startup / app crash** | Bad command/args, app crash (check logs), OOMKilled (check `describe pod` for last state) |
| Pod in ImagePullBackOff | **Image / registry** | Wrong image name or tag, private registry without pull secret |
| Pod in Pending | **Resource constraints / storage** | Insufficient CPU/memory on node, unbound PVC, no matching StorageClass, node taints |
| Pod in Init:CrashLoopBackOff or Init:0/1 | **Init container** | Init container failing — check logs of init container specifically: `kubectl logs <pod> -c <init-container-name>` |
| Pod Running but not Ready | **Health probes** | Readiness probe wrong path, wrong port, or initialDelaySeconds too short |
| Pod Running + Ready but restarts climbing | **Liveness probe** | Liveness probe too aggressive or wrong endpoint, killing healthy containers |
| All pods Running + Ready but app unreachable via Service | **Service routing** | Selector mismatch, wrong port/targetPort, empty endpoints |
| All pods + services look healthy but traffic times out silently | **Network policies** | NetworkPolicy blocking traffic — everything looks correct but packets are dropped |
| Service works (port-forward succeeds) but external URL fails | **Ingress** | Wrong backend service or port, missing IngressClass, bad path rules |
| Pods Running + Ready but app returns 5xx | **Application-level** | Wrong DB credentials, wrong host, dependency not reachable — logs tell the real story |
| Deploy exists but new pods not rolling out | **Deployment / rollout** | Bad image on new ReplicaSet, maxUnavailable=0 with failing readiness, stuck rollout |
| Resources seem to be missing entirely | **Namespace confusion** | Resources deployed to wrong namespace — check `kubectl get all -A` |
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
Look for: wrong subject name/namespace/kind in binding, wrong roleRef, missing verbs/resources/apiGroups.

**Pod startup / app crash / OOMKill:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -n drill
kubectl logs <pod> -n drill --previous
```
Sub-branches: check exit code (137 = OOMKill, 1 = app error), check resource limits in describe output, check last state.

**Image / registry:**
```
kubectl describe pod <pod> -n drill
```
Check Events section for pull error message — usually tells you exact image and reason.

**Resource constraints:**
```
kubectl describe pod <pod> -n drill
kubectl describe node
kubectl top nodes
```
Look for: "Insufficient cpu" or "Insufficient memory" in Events. Compare pod requests to node allocatable.

**Init containers:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -c <init-container-name> -n drill
```
Note: `kubectl logs <pod>` without `-c` shows the main container. Init container logs require specifying the container name.

**Health probes:**
```
kubectl describe pod <pod> -n drill
kubectl logs <pod> -n drill
```
Look for: Readiness/Liveness probe failed messages in Events. Compare probe spec to actual app endpoint. Test with `kubectl exec` or `port-forward`.

**Service routing:**
```
kubectl describe svc <svc> -n drill
kubectl get endpoints <svc> -n drill
kubectl get pods -n drill --show-labels
```
Look for: empty endpoints = selector mismatch. Compare service selector to pod labels exactly. Test with `kubectl port-forward svc/<svc> 8080:<port> -n drill`.

**Network policies:**
```
kubectl get networkpolicy -n drill
kubectl describe networkpolicy -n drill
```
Look for: default deny with missing allow rules, wrong podSelector, wrong namespaceSelector, missing port in ingress/egress rules. Hard to diagnose — if everything else looks correct and traffic still fails, this is the bucket. Test by temporarily deleting the policy.

**Ingress:**
```
kubectl describe ingress <ingress> -n drill
kubectl get svc -n drill
kubectl get endpoints <svc> -n drill
```
Look for: wrong backend service name or port, missing IngressClass, no address assigned. Test underlying service with port-forward to isolate whether the issue is Ingress or Service.

**Application-level:**
```
kubectl logs <pod> -n drill
kubectl exec <pod> -n drill -- env
kubectl get configmap <cm> -n drill -o yaml
kubectl get secret <secret> -n drill -o yaml
```
Look for: connection refused, auth failed, wrong database name in logs. Cross-reference env vars in pod with actual ConfigMap/Secret values.

**Deployment / rollout:**
```
kubectl rollout status deploy/<deploy> -n drill
kubectl rollout history deploy/<deploy> -n drill
kubectl get rs -n drill
kubectl describe deploy <deploy> -n drill
```
Look for: new ReplicaSet with 0 ready, old ReplicaSet still at full count. Fix options: `kubectl rollout undo`, `kubectl set image`, or fix the underlying issue.

**Storage:**
```
kubectl get pvc -n drill
kubectl get pv
kubectl get storageclass
kubectl describe pvc <pvc> -n drill
```
Look for: PVC stuck in Pending, no matching PV or StorageClass, access mode conflict, capacity mismatch.

**Configuration injection:**
```
kubectl describe pod <pod> -n drill
kubectl get configmap -n drill
kubectl get secret -n drill
kubectl get pod <pod> -n drill -o yaml
```
Look for: warning events about missing ConfigMap/Secret, wrong name in envFrom reference, key name mismatch. Compare what the pod spec references to what actually exists.

**Namespace confusion:**
```
kubectl get all -A
kubectl get ns
```
Look for: resources exist but in a different namespace. The fix might be moving resources or correcting a deployment target namespace.

### Narration examples (use these to coach the user)

If the user is silent during debugging, or if their narration is weak, suggest phrasing like these in the post-scenario feedback:

- "I'm starting with `get all` to see the full picture before I dive in."
- "I see the pod is in CrashLoopBackOff — let me check logs to understand why it's crashing."
- "Endpoints are empty, which tells me the service selector doesn't match any pod labels. Let me compare them."
- "Everything looks healthy from a Kubernetes perspective — pods are Running, endpoints are populated. So this is probably an application-level issue. Let me check the logs."
- "The pod is Pending. I want to check if it's a resource issue or a storage issue — `describe pod` should tell me."
- "I see `Init:0/1` — this pod has an init container that hasn't completed. Let me get the init container logs specifically."
- "I've applied the fix. Now I'm going to verify end-to-end — not just that pods are running, but that I can actually reach the app and get a valid response."
- "My theory is [X]. Let me test that by running [Y]. If I'm wrong, I'll reconsider."

### Important rules for Phase 2
- NEVER run diagnostic or fix commands on behalf of the user during a scenario. You are the interviewer, not the engineer.
- NEVER reveal the failure domain or category in the symptom description.
- NEVER skip the verification step after a fix.
- NEVER introduce a new scenario without restoring health first.
- Keep a running tally of which failure domains have been covered and mention it when asked.
- If the user asks "how am I doing overall", give a summary of patterns across scenarios — strengths and areas to improve.

---

## Phase 3 — Guided Coaching Mode

**Trigger:** The user says "coach me on this one", "help me through this", "switch to coaching mode", or similar. Can also be triggered mid-scenario in Phase 2 if the user asks for active guidance.

**Goal:** Actively coach the user through a troubleshooting scenario step by step. Unlike Phase 2 (where you stay silent), here you guide the user at each step — telling them what to notice, what to say out loud, and what to do next.

### When to use this

- The user hits a failure domain they're weak on and wants to learn the pattern before trying independently.
- The user is stuck in Phase 2 and wants to switch from "test me" to "teach me" for the current scenario.
- The user wants to walk through a specific bucket's diagnostic flow with guidance.

### How it works

The user runs commands in their debug terminal and either pastes the output or says "check the log." If they say check the log, read `~/code/platform-drill-fastapi-postgres/drill-session.log` to see their latest commands and output. Respond with structured coaching using this exact format:

```
### What I See
(2-4 bullet points: key signals in the output the user should notice)

### Working Theory
(1-2 sentences. Frame as hypothesis, not conclusion. e.g. "This looks like a selector mismatch — the service can't find the pods." If too early to tell, say so.)

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
7. **Follow the triage methodology** from Phase 2's reference section. Guide the user through the same steps: universal triage → identify bucket → bucket-specific commands → fix → verify.

### Transitioning back to Phase 2

When the user says "back to phase 2", "test me again", or "I want to try independently", switch back to Phase 2 mode (silent interviewer). If a scenario was in progress, restore the cluster to healthy and start a new one.