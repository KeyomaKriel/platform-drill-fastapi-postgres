# Kubernetes Troubleshooting Playbook

## Table of Contents

- [Rule 0](#rule-0)
- [Phase 1: Orient and Triage](#phase-1-orient-and-triage)
- [Quick Signal Table](#quick-signal-table)
- The Buckets
  - [Bucket A: RBAC / Identity / Permissions](#bucket-a)
  - [Bucket B: Pod / Startup / Scheduling / Workload Health](#bucket-b)
  - [Bucket C: Deployment / Rollout](#bucket-c)
  - [Bucket D: Service / Internal Reachability](#bucket-d)
  - [Bucket E: Ingress / External Routing](#bucket-e)
  - [Bucket F: Config / Secret / Volume / Dependency Setup](#bucket-f)
  - [Bucket G: Jobs / CronJobs](#bucket-g)
  - [Bucket H: Application-Level Failures](#bucket-h)
  - [Bucket I: Network Policies](#bucket-i)
  - [Bucket J: Storage](#bucket-j)
  - [Bucket K: Namespace Confusion](#bucket-k)
- [Quick Reference — Most Useful Commands](#quick-reference)
- [The Process (Summary)](#process-summary)
- [Appendix A: Linux / Bash / Zsh Commands](#appendix-linux)
- [Appendix B: kubectl Commands](#appendix-kubectl)
- [Appendix C: Git Commands](#appendix-git)
- [Appendix D: HTTP Status Codes](#appendix-http)
- [Appendix E: Exit Codes, Pod Statuses, and Error Reasons](#appendix-exit-codes)

---

<a id="rule-0"></a>
## Rule 0

Do not start by guessing the root cause.

Start by answering:

1. What is the visible symptom?
2. Which Kubernetes object type is closest to that symptom?
3. What command will show the truth fastest?

---

<a id="phase-1-orient-and-triage"></a>
## Phase 1: Orient and Triage

Say: *"I'm starting with triage to identify the failure category. I'm checking context, namespaces, core workloads, services, ingress, resource usage, and recent events. Once I see the strongest signal, I'll stop broad triage and switch to the relevant branch."*

Work through these commands in order. Each command is followed by what to look for before moving to the next one.

---

#### `kubectl config current-context`

Look for:

- whether you are on the expected cluster/context

Stop and switch direction if:

- the scenario clearly expects a different cluster/context

**Fix patterns:**

- switch to the correct context:

```bash
kubectl config use-context <correct-context>
```

- if the interview/scenario provides a kubeconfig file, export or use it explicitly:

```bash
export KUBECONFIG=<path-to-kubeconfig>
```

**Verify:**

```bash
kubectl config current-context
kubectl config view --minify
```

You are done with this check when the current context matches the scenario and the cluster responds as expected.

---

#### `kubectl get ns`

Look for:

- likely app namespace
- scenario-specific namespace mentioned in prompt

Stop and switch direction if:

- the prompt names a namespace and you were looking elsewhere

Once you identify the target namespace, set it as the default so you don't have to repeat `-n` on every command:

```bash
kubectl config set-context --current --namespace=<ns>
```

**Fix patterns:**

- if resources were applied to the wrong namespace, re-apply or move them correctly rather than continuing to inspect the wrong place

**Verify:**

```bash
kubectl get ns
kubectl get pods -n <expected-ns>
kubectl config view --minify | grep namespace -A2
```

You are done with this check when you are consistently inspecting the namespace that the scenario actually uses.

---

#### `kubectl get pods -A`

Look for these statuses:

- CrashLoopBackOff
- ImagePullBackOff / ErrImagePull / ErrImageNeverPull
- Pending
- Error
- OOMKilled (check `kubectl describe` for LastState)
- Init:CrashLoopBackOff / Init:0/1 / Init:Error
- Completed (for Jobs)
- Running but suspicious restart count
- Running but READY shows 0/1

If you see any of those, you likely have a workload/pod bucket. Move to [**Bucket B**](#bucket-b).

Do not keep scanning forever once you find an obviously broken pod tied to the scenario.

**Fix patterns:**

- no fix here yet; this command is mainly to identify the broken workload quickly
- once a suspicious pod is found, stop broad scanning and move into [Bucket B](#bucket-b) rather than trying to "fix" from `get pods` output alone

**Verify:**

- verify only that you have identified the most likely broken pod tied to the scenario
- then continue in [Bucket B](#bucket-b)

---

#### `kubectl get deploy -A`

Look for:

- READY 0/1, 1/2, etc.
- AVAILABLE lower than desired
- app deployment not healthy

If deployments are unhealthy and pods are also unhealthy, still go to [**Bucket B**](#bucket-b).

If deployment is unhealthy but pods are not obviously failing, go to [**Bucket C**](#bucket-c).

**Fix patterns:**

- no direct fix from this command alone
- use it to decide whether the problem belongs in [Bucket B](#bucket-b) or [Bucket C](#bucket-c)

**Verify:**

- verify only that you have identified whether the deployment problem is really a pod problem underneath, or a rollout/deployment-level issue

---

#### `kubectl get svc -A`

Look for:

- service exists or missing
- expected port exposure
- ClusterIP / NodePort / LoadBalancer

Do not jump into service debugging yet unless:

- the scenario says app is unreachable
- pods look healthy
- deployment looks healthy

Then go to [**Bucket D**](#bucket-d).

**Fix patterns:**

- if the expected service is missing, you will likely need to create/apply the correct Service manifest
- if the wrong service type is clearly being used, you may need to patch or edit it later in [Bucket D](#bucket-d)
- otherwise, do not fix from here; move to [Bucket D](#bucket-d)

**Verify:**

- verify that the service you expect actually exists
- if the service is missing, fix that and then re-run:

```bash
kubectl get svc -n <ns>
```

---

#### `kubectl get ingress -A`

Look for:

- ingress exists or missing
- address assigned or not

Do not jump into ingress yet unless:

- the symptom is external access / URL / host/path routing
- service/pods are likely healthy

Then go to [**Bucket E**](#bucket-e).

**Fix patterns:**

- if ingress is missing, you may need to create/apply the expected Ingress resource
- if the scenario is not about external routing, do not touch ingress yet
- if ingress exists but the service path below it is broken, leave ingress alone and go back to [Bucket D](#bucket-d) first

**Verify:**

- verify that ingress existence matches the scenario expectation:

```bash
kubectl get ingress -n <ns>
```

---

#### `kubectl top nodes` / `kubectl top pods -A`

Look for:

- nodes at or near CPU/memory capacity
- individual pods consuming unexpected resources
- OOMKilled signals (high memory usage before restart)

If a node is full and pods are Pending, this is a scheduling/resource problem → [**Bucket B**](#bucket-b).

Note: if Metrics API is not available, skip this step — it's confirmatory, not diagnostic.

**Fix patterns:**

- no direct fix from here; use to confirm whether resource pressure is the root cause
- if a pod is consuming far more than expected, investigate its resource limits in [Bucket B](#bucket-b)

**Verify:**

- verify that node/pod resource usage is consistent with the symptoms you see in other triage commands

---

#### `kubectl get events -A --sort-by=.metadata.creationTimestamp`

Look near the newest events for:

- Forbidden
- FailedScheduling
- FailedMount
- FailedPull / Failed to pull image
- Unhealthy (probe failure)
- Back-off restarting
- secret/configmap not found
- OOMKilling

This command often tells you the bucket directly:

- Forbidden → [**Bucket A**](#bucket-a): RBAC / identity
- FailedScheduling / PVC issues → [**Bucket B**](#bucket-b)
- Unhealthy probe / restart loop / OOMKilled → [**Bucket B**](#bucket-b)
- mount/config errors → [**Bucket F**](#bucket-f): Config / secret / volume

**Fix patterns:**

- do not try to fix from the events list in isolation
- use the event wording to choose the correct bucket, then inspect the owning object in detail
- if the newest event clearly names the missing object or denied action, go straight to that bucket and confirm there

**Verify:**

- verify that the event signal is consistent with the bucket you choose
- after fixing later, re-run:

```bash
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

and confirm the error event is no longer recurring.

---

### When to shortcut triage

Sometimes the scenario prompt or task wording gives you a strong enough cue to skip broad triage and start in a specific bucket. This is about choosing a **starting point**, not assuming root cause — you still verify once you get there.

Two types of cue:

- **Prompt cues** — the interview/task wording names a specific failure type. Example: *"the service account is getting Forbidden"* tells you to start in RBAC. You haven't run any commands yet, but the wording is specific enough to skip straight there.
- **Observed signals** — you run one or two commands and immediately see an obvious status (CrashLoopBackOff, Pending, empty endpoints). No need to finish the full triage sequence — commit to the bucket that matches.

If neither type of cue is strong, run the full triage. It takes under a minute.

The [Quick Signal Table](#quick-signal-table) below covers both: prompt cues in the left column and observed signals from command output.

---

### Flowchart Fast Path

Use the Fast Path when you already know which app/workload is broken and the symptom is "this app is not working." Examples: *"The app is down"*, *"Users can't reach this service"*, *"The pod keeps restarting"*, *"The new rollout failed."*

Use full triage when the scope is ambiguous, multiple things look broken, or you don't know which namespace/workload matters. Examples: *"Please investigate this cluster"*, *"Production is having issues"*, *"Find what's wrong."*

The simplest rule: **known app + known symptom + unknown cause = Fast Path.** Unknown app + unknown scope = full triage.

Say: *"This looks like a single workload problem, so I'm going straight to pods, then logs, then testing reachability layer by layer."*

1. `kubectl get pods -n <ns>` — check pod status. If broken (Pending, CrashLoopBackOff, ImagePullBackOff, Running but not Ready), go to [Bucket B](#bucket-b).
2. `kubectl describe pod <pod> -n <ns>` and `kubectl logs <pod> -n <ns>` — identify the specific failure from Events, exit codes, and log output.
3. If pods are healthy, test pod reachability directly: `kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>` then `curl localhost:8080/`. If this fails, the app itself is broken — check logs, command, env vars ([Bucket H](#bucket-h) or [Bucket F](#bucket-f)).
4. If pod is reachable, test service: `kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>` then `curl localhost:8080/`. If this fails, go to [Bucket D](#bucket-d).
5. If service works, test ingress: `curl localhost/` or `curl -H "Host: <host>" localhost/`. If this fails, go to [Bucket E](#bucket-e).

This is not a one-way decision. You can start with broad triage, get a signal from `get pods -A` or events, and switch into the Fast Path at any point. That is usually the safest pattern: 20–40 seconds of orientation, then commit.

---

<a id="quick-signal-table"></a>
## Quick Signal Table

Now that you have a signal — from triage commands, from the Fast Path, or from the prompt itself — use this table to jump to the right bucket.

| What you see or hear | Bucket | Go to |
|---|---|---|
| Forbidden / Unauthorized / "service account can't do X" | **RBAC** | [Bucket A](#bucket-a) |
| Pod status: `ImagePullBackOff`, `ErrImagePull`, or `ErrImageNeverPull` | **Image / registry** | [Bucket B](#bucket-b) → ImagePull sub-branch |
| Pod status: `Pending` / "pods won't schedule" | **Scheduling / resources / storage** | [Bucket B](#bucket-b) → Pending sub-branch |
| Pod status: `CrashLoopBackOff` / "app keeps restarting" | **Pod startup / app crash** | [Bucket B](#bucket-b) → CrashLoop sub-branch |
| Pod `Running` but READY shows `0/1` | **Readiness probe** | [Bucket B](#bucket-b) → Running-not-Ready sub-branch |
| Pod `Running` + `1/1` but RESTARTS climbing | **Liveness probe** | [Bucket B](#bucket-b) → Liveness sub-branch |
| Pod status: `Init:CrashLoopBackOff` or `Init:0/1` | **Init container** | [Bucket B](#bucket-b) → Init container sub-branch |
| Pod exit code 137 / OOMKilled in describe | **Resource limits** | [Bucket B](#bucket-b) → CrashLoop sub-branch (OOMKilled) |
| Deployment unhealthy but pods not obviously broken / "deploy went out but new version isn't running" | **Deployment / rollout** | [Bucket C](#bucket-c) |
| Pods healthy but app unreachable through Service | **Service routing** | [Bucket D](#bucket-d) |
| Service works (port-forward OK) but external URL fails / "users can't reach the app" | **Ingress** | [Bucket E](#bucket-e) |
| Events show missing ConfigMap or Secret / "app fails after config change" | **Configuration injection** | [Bucket F](#bucket-f) |
| "Cronjob not running" / issue is batch or scheduled execution | **Jobs / CronJobs** | [Bucket G](#bucket-g) |
| Pods Running + Ready but app returns 5xx errors | **Application-level** | [Bucket H](#bucket-h) |
| Everything looks healthy but traffic silently times out | **Network policies** | [Bucket I](#bucket-i) |
| PVC stuck in `Pending` / "pod can't start, volume issue" | **Storage** | [Bucket J](#bucket-j) |
| Resources appear to be missing entirely / "I can't find the pods" | **Namespace confusion** | [Bucket K](#bucket-k) |

If multiple signals compete, pick the one closest to the root. Pod issues before Service issues. Config issues before app crash issues.

Say: *"The strongest signal I'm seeing is [X], so I'm treating this as a [bucket] problem. Let me dig into that specifically."*

---

## The Buckets

---

<a id="bucket-a"></a>
### Bucket A: RBAC / Identity / Permissions

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** you saw Forbidden, Unauthorized, or a service account/user cannot perform an action.

Say: *"I see a Forbidden error, so this is an RBAC problem. I need to check the ServiceAccount, the Role, and the RoleBinding to find the broken link in the chain."*

#### Diagnose

Say: *"I'm entering the RBAC bucket because the signal is a Forbidden or Unauthorized error — that always means a missing or misconfigured permission grant. I'll walk the full chain: ServiceAccount exists, RoleBinding points to the right SA, and the Role actually grants the right verbs."*

```bash
kubectl auth can-i --list
kubectl get sa,role,rolebinding,clusterrole,clusterrolebinding -A
```

If the scenario names a service account:

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> create deployments -n <ns>
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> get pods -n <ns>
kubectl get sa <sa> -n <ns> -o yaml
kubectl get role <role> -n <ns> -o yaml
kubectl get rolebinding <binding> -n <ns> -o yaml
```

#### What to look for

**`kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>`**
- Healthy: `yes`
- Broken: `no` — the permission chain is broken somewhere; use the SA, Role, and RoleBinding steps below to find the gap.

**`kubectl get sa <sa> -n <ns> -o yaml` — check that the ServiceAccount exists**
- Healthy: the SA is returned with the correct `metadata.name` and `metadata.namespace`
- Broken: `Error from server (NotFound)` — the SA was never created, or the Deployment references a different name; check `kubectl get pod <pod> -n <ns> -o yaml` field `spec.serviceAccountName` and compare to what exists

**`kubectl get rolebinding <binding> -n <ns> -o yaml` — check `subjects` and `roleRef`**

`subjects` field:
- `kind` — Healthy: `ServiceAccount`. Broken: `User` or `Group` when a ServiceAccount is expected
- `name` — Healthy: exact match to the SA name. Broken: any typo or case difference (e.g. `app` when SA is `app-sa`)
- `namespace` — Healthy: matches the namespace where the SA lives. Broken: wrong namespace or field omitted — the binding silently won't match

`roleRef` field:
- `name` — Healthy: exact match to the Role name. Broken: points to a role that doesn't exist; `kubectl get role -n <ns>` to see what actually exists
- `kind` — Healthy: `Role` for namespace-scoped, `ClusterRole` for cluster-wide. Broken: kind mismatch causes silent failure

**`kubectl get role <role> -n <ns> -o yaml` — check `rules`**

Each rule has three fields — all three must be correct:

| Field | Healthy example | Broken example |
|---|---|---|
| `apiGroups` | `[""]` for core resources (pods, services, secrets); `["apps"]` for Deployments | `["v1"]` — wrong; core API group is `""` not `"v1"` |
| `resources` | `["pods","services"]` | `["pod"]` — singular form is not accepted; must be plural |
| `verbs` | `["get","list","watch"]` | `["read"]` — `read` is not a valid verb |

If unsure about API group:

```bash
kubectl api-resources | grep <resource>
kubectl explain <resource>
```

**Common apiGroup reference:**

- `deployments`, `replicasets`, `statefulsets` → apiGroups: `["apps"]`
- `pods`, `services`, `configmaps`, `secrets`, `serviceaccounts` → apiGroups: `[""]`
- `ingresses`, `networkpolicies` → apiGroups: `["networking.k8s.io"]`
- `jobs`, `cronjobs` → apiGroups: `["batch"]`

#### Stop condition

Stop when `kubectl auth can-i` returns `yes` for all required permissions AND there are no Forbidden errors in pod logs.

Say: *"I've confirmed the issue is [subject name mismatch / missing verb / wrong apiGroup]. Here's my fix plan: I'm going to [edit the RoleBinding / edit the Role / delete and recreate the binding]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Subject name or namespace wrong in RoleBinding:** Find the correct SA name with `kubectl get pod <pod> -n <ns> -o yaml | grep serviceAccountName`. Fix with `kubectl edit rolebinding <binding> -n <ns>` — correct `subjects[].name` and `subjects[].namespace`. Verify: `kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>` returns `yes`.

**RoleRef name wrong (binding points to nonexistent Role):** Find the correct Role name from `kubectl get role -n <ns>`. Note: `roleRef` is immutable — you must delete and recreate:

```bash
kubectl delete rolebinding <binding> -n <ns>
kubectl create rolebinding <binding> \
  --role=<correct-role> \
  --serviceaccount=<ns>:<sa> \
  -n <ns>
```

Verify: `kubectl auth can-i` returns `yes`.

**Role rules missing verb, resource, or apiGroup:** Find the required verb/resource from the error message in pod logs (e.g. `cannot list resource "deployments" in API group "apps"`). Fix with `kubectl edit role <role> -n <ns>` — add the missing entry to `rules[]`. Verify: `kubectl auth can-i` returns `yes`.

**ServiceAccount does not exist:** Fix with `kubectl create serviceaccount <sa> -n <ns>`. If a RoleBinding is also missing: `kubectl create rolebinding <binding> --role=<role> --serviceaccount=<ns>:<sa> -n <ns>`. Verify: `kubectl get sa <sa> -n <ns>` returns the SA; `kubectl auth can-i` returns `yes`.

#### Verify

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
# Expected: yes
kubectl get sa,role,rolebinding -n <ns>
# Expected: all three objects present with correct names
```

Say: *"Permission check returns yes, the RBAC chain is consistent, and there are no Forbidden errors in the application logs. RBAC is healthy."*

---

<a id="bucket-b"></a>
### Bucket B: Pod / Startup / Scheduling / Workload Health

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** you saw broken pod states, unhealthy restarts, resource pressure, or events pointing at pod-level failure.

Say: *"I see a pod in [status]. Let me describe it and check logs to understand what's happening."*

#### Diagnose

Say: *"I'm entering the pod health bucket because the signal is at the pod level — a bad status, restart count climbing, or an event pointing here. Before I branch into a sub-problem I want the full picture from describe and logs so I'm not guessing at the cause."*

```bash
kubectl get pods -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

**Multi-container pods:** if the pod has init containers or sidecars, target the specific container:

```bash
kubectl logs <pod> -c <container> -n <ns>
kubectl logs <pod> -c <init-container> -n <ns>
kubectl describe pod <pod> -n <ns>   # check initContainerStatuses section
```

#### What to look for

**`kubectl get pods -n <ns>` — STATUS and RESTARTS columns**

| STATUS | What it signals | Branch to |
|---|---|---|
| `Pending` | Not scheduled — resource pressure, unbound PVC, or node taint | Pending sub-branch |
| `Init:0/1` or `Init:CrashLoopBackOff` | Init container has not completed or is failing | Init Container sub-branch |
| `ImagePullBackOff` / `ErrImagePull` / `ErrImageNeverPull` | Image cannot be pulled | ImagePull sub-branch |
| `CrashLoopBackOff` | Container starts and immediately exits repeatedly | CrashLoop sub-branch |
| `Running` but READY shows `0/1` | Container is up but failing readiness probe | Readiness sub-branch |
| `Running` with RESTARTS climbing | Container killed and restarted by liveness probe | Liveness sub-branch |

Healthy: `Running` with READY `1/1` and RESTARTS `0` (or stable low number not climbing).

**`kubectl describe pod <pod> -n <ns>` — `State` and `Last State` under each container**

- Healthy `State`: `Running` with a recent `Started` timestamp
- Broken `State`: `Waiting` with `Reason: CrashLoopBackOff` or `Reason: ImagePullBackOff`
- `Last State` exit codes: `0` = clean exit (unexpected for long-running app), `1` = application error (check logs), `137` = OOMKill (check memory limits), `143` = SIGTERM (usually liveness probe kill)

**`kubectl describe pod <pod> -n <ns>` — `Conditions` section**

- Healthy: all conditions `True` (`PodScheduled`, `Initialized`, `ContainersReady`, `Ready`)
- Broken: any condition `False` with a `Message` — read the message before going further

**`kubectl describe pod <pod> -n <ns>` — `Events` section (bottom)**

| Event reason | Meaning |
|---|---|
| `FailedScheduling` | Cannot place pod — check message for `Insufficient cpu/memory`, `untolerated taint`, or `no persistent volumes` |
| `FailedMount` | Volume cannot attach — PVC unbound, wrong StorageClass, or missing ConfigMap/Secret |
| `BackOff` | Container restarting repeatedly |
| `Pulling` / `Pulled` | Image pull in progress or completed; absence of `Pulled` with a `Failed` event = ImagePull problem |
| `Unhealthy` | Probe failed — message says which probe and the exact error |
| `Killing` | Liveness probe killed the container — repeating = probe too aggressive or wrong target |

**`kubectl describe pod <pod> -n <ns>` — `Limits` and `Requests`**

- Check when pod is Pending or exit code is 137
- Broken: requests higher than node allocatable (causes Pending), or limits too low (causes OOMKill)
- Node capacity: `kubectl describe node | grep -A 5 Allocatable`

**`kubectl logs <pod> -n <ns>` and `--previous`**

- Use `--previous` when container has already exited — `logs` without it returns nothing for a crashed container
- Healthy: clean startup messages, no stack traces
- Broken: `connection refused` (dependency down → [Bucket H](#bucket-h)), `auth failed` (wrong credentials → [Bucket F](#bucket-f)), missing env var (→ [Bucket F](#bucket-f)), panic/stack trace (app bug)

Now branch based on the pod status:

---

#### Sub-branch: ImagePullBackOff / ErrImagePull / ErrImageNeverPull

Say: *"The pod can't pull its container image. I need to check whether it's a wrong image name, a wrong tag, or a registry access issue."*

Note: `ErrImageNeverPull` means `imagePullPolicy: Never` is set but the image doesn't exist locally on the node. Common in kind/minikube clusters where images are loaded directly rather than pulled from a registry.

```bash
kubectl describe pod <pod> -n <ns>
kubectl describe deploy <deploy> -n <ns>
```

Look for: wrong image name, wrong tag, auth issue, image pull secret missing/wrong. The Events section usually says exactly what image it tried to pull and why it failed.

**Stop condition:** Stop when the event clearly shows the pull problem — wrong name, wrong tag, or auth failure.

**To find the working image tag** when it was changed and you don't know what it was before:

```bash
# Check what the old (still running) pod is using
kubectl get pod <old-pod> -n <ns> -o jsonpath='{.spec.containers[0].image}'

# Or check the old ReplicaSet
kubectl get rs <old-rs> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Fix patterns:**

- correct the image repository/path
- correct the image tag
- add/fix imagePullSecrets
- fix registry credentials
- if the image does not exist, push/build the correct image or point to a valid tag
- `kubectl rollout undo` reverts the entire pod template to the previous revision — use when you want a full rollback
- `kubectl set image` changes only the image — use when other spec changes in the current revision are intentional

```bash
# Fix image name or tag
kubectl set image deployment/<deploy> <container>=<correct-image>:<correct-tag> -n <ns>

# If you don't know the container name
kubectl get deployment <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[*].name}'

# Create image pull secret
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <ns>

# Patch SA to use the pull secret
kubectl patch serviceaccount default -n <ns> \
  -p '{"imagePullSecrets": [{"name": "<secret-name>"}]}'
```

**Verify:**

```bash
kubectl get pod <pod> -n <ns> -w
kubectl describe pod <pod> -n <ns>
```

You are done when the pod pulls successfully and moves past the image pull error state.

---

#### Sub-branch: Pending → Scheduling / Resources / Storage

Say: *"The pod is Pending, which means it hasn't been scheduled to a node. I want to find out why — it's usually either a resource constraint, a storage issue, or a node taint/affinity problem."*

```bash
kubectl describe pod <pod> -n <ns>
kubectl top nodes
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
```

Look for: insufficient resources, unbound PVC, node taints/selectors, storage class issue.

**Stop condition:** Stop when the scheduler or PVC message clearly identifies the blocker.

| Event message | Cause | Fix |
|---|---|---|
| `Insufficient cpu` or `Insufficient memory` | Resource requests too high for available nodes | Lower the requests |
| `no nodes available to schedule` | No nodes match (taints, affinity, etc.) | Check node taints and pod tolerations |
| `unbound immediate PersistentVolumeClaim` | PVC can't bind | Go to [Bucket J](#bucket-j) (Storage) |

**Fix patterns:**

- reduce CPU/memory requests if they are unschedulable
- fix or remove node selectors / affinity rules that cannot be satisfied
- add tolerations if the pod must run on tainted nodes
- create/fix the PVC
- use the correct storageClassName
- fix access mode or requested storage size if it is invalid for the environment

```bash
# If resource request is too high
kubectl edit deploy <deploy> -n <ns>
# Lower resources.requests.cpu or resources.requests.memory

# If PVC is unbound — check StorageClass
kubectl get sc
kubectl describe pvc <pvc> -n <ns>
# Fix storageClassName or create missing StorageClass

# If taint is blocking
kubectl describe node <node>
kubectl taint nodes <node> <key>:<effect>-
```

**Verify:**

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pvc -n <ns>
kubectl get pods -n <ns>
```

You are done when the pod is scheduled and no longer blocked in Pending for the same reason.

---

#### Sub-branch: CrashLoopBackOff / Repeated Restarts

Say: *"The container is starting and then crashing repeatedly. I need to check the logs to understand why it's crashing."*

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -c <container> -n <ns>   # if multi-container
kubectl describe pod <pod> -n <ns>
```

Look for: app crash, bad config, probe misconfiguration, dependency failure, OOMKilled.

**Stop condition:** Stop when you identify the crash cause from logs or describe output.

Check the exit code in `describe pod` under `Last State`:

| Exit code | Meaning | Next step |
|---|---|---|
| `0` | Container exited successfully (shouldn't restart) | Check `restartPolicy`, command/args |
| `1` | Application error | Read the logs carefully |
| `137` | OOMKilled (out of memory) | Raise resource limits |
| `139` | Segfault | Image/binary issue |

OOMKilled means the process exceeded the container memory limit. First confirm that in describe pod and compare usage with kubectl top pod. Then decide whether the fix is to increase memory limits/requests or reduce app memory usage. Don’t just raise the limit blindly.

**Fix patterns:**

- fix the app command/args
- correct environment variables
- fix secret/configmap references
- correct dependency endpoints/credentials
- fix the probe path/port/timing
- roll back a bad image or bad config change
- if OOMKilled, raise memory limit

```bash
# Fix probe (wrong path, port, or timing)
kubectl edit deploy <deploy> -n <ns>
# Correct livenessProbe/readinessProbe path, port, initialDelaySeconds

# If OOMKilled — raise memory limit
kubectl edit deploy <deploy> -n <ns>
# Increase resources.limits.memory

# Fix app config, then restart
kubectl edit configmap <cm> -n <ns>
kubectl rollout restart deploy <deploy> -n <ns>

# Roll back a bad image
kubectl rollout undo deploy/<deploy> -n <ns>

# Fix command/args
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 5 "command\|args"
kubectl edit deployment <deploy> -n <ns>
```

**Verify:**

```bash
kubectl get pods -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
```

You are done when restarts stop climbing, the pod stays up, and the failure no longer recurs.

---

#### Sub-branch: Running but not Ready → Readiness Probe

Say: *"The pod is Running but not Ready — the readiness probe is failing. The pod won't receive traffic until it passes. Let me check what the probe is doing and whether the app actually responds on that path and port."*

```bash
kubectl describe pod <pod> -n <ns>
```

Look for `Readiness probe failed` messages in Events. Check the probe spec under `Containers: → Readiness:` for the path, port, initialDelaySeconds, and periodSeconds.

Test the probe manually:

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i http://localhost:8080
curl -i http://localhost:8080/health
curl -i http://localhost:8080/readyz
```

Look for: does app respond? correct health path? correct port?

**Stop condition:** Stop when you know whether the probe path is wrong, the probe port is wrong, the timing is too aggressive, or the app is genuinely unhealthy.

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path | Path doesn't match an actual app endpoint | Edit the deployment, fix the path |
| Wrong probe port | Port doesn't match the container's listening port | Edit the deployment, fix the port |
| initialDelaySeconds too short | App takes longer to start than the probe allows | Increase initialDelaySeconds |
| App actually unhealthy | Probe is correct but app has a real problem | Check logs — go to [Bucket H](#bucket-h) |

**Fix patterns:**

```bash
kubectl edit deploy <deploy> -n <ns>
# Correct readinessProbe.httpGet.path or .port or .initialDelaySeconds
```

**Verify:**

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns>
kubectl get endpoints <svc> -n <ns>
curl -i http://localhost:8080/health
```

You are done when the pod becomes Ready and starts serving traffic normally. Endpoints should populate once the pod is Ready.

---

#### Sub-branch: Running + Ready but Restarts Climbing → Liveness Probe

Say: *"The pod shows Running and Ready, but the restart count keeps going up. That means the liveness probe is periodically failing and Kubernetes is killing the container. I need to check if the probe is misconfigured or if the app is genuinely becoming unhealthy."*

```bash
kubectl describe pod <pod> -n <ns>
```

Look for `Liveness probe failed` in Events. Check the liveness probe spec. Common pattern: the probe endpoint is too slow under load, or the timeout/period is too aggressive.

**Stop condition:** Stop when you know whether the probe path/port is wrong, the timing is too aggressive, or the app has a genuine health issue.

**Fix patterns:**

```bash
kubectl edit deploy <deploy> -n <ns>
```

Options:
- Fix the probe path or port
- Increase `timeoutSeconds` (default is 1, often too short)
- Increase `periodSeconds`
- Increase `failureThreshold` (how many failures before kill)
- Increase `initialDelaySeconds` if the app needs more startup time

**Verify:**

```bash
kubectl get pods -n <ns> -w
```

Watch for a few minutes. Restart count should stop climbing.

---

#### Sub-branch: Init Container Failure

Say: *"I see `Init:0/1` which means there's an init container that hasn't completed. The main container won't start until it succeeds. Let me check the init container logs specifically."*

First, find the init container name:

```bash
kubectl describe pod <pod> -n <ns>
```

Look under `Init Containers:` for the container name and its state.

Then check its logs:

```bash
kubectl logs <pod> -c <init-container-name> -n <ns>
```

**Important:** `kubectl logs <pod>` without `-c` shows the main container, which hasn't started yet and will have no logs.

**Stop condition:** Stop when you know why the init container is failing — wrong command, can't reach a dependency, NetworkPolicy blocking, or missing config.

| Symptom | Cause | Fix |
|---|---|---|
| Init container loops waiting for a service | Target service doesn't exist or is in wrong namespace | Create the missing service or fix the hostname |
| Init container can't connect to a port | NetworkPolicy blocking egress, or target pod not ready | Check [NetworkPolicies (Bucket I)](#bucket-i) or target pod status |
| Init container exits with error | Bad command, wrong image, missing config | Read the logs, fix the command/image/config |

**Fix patterns:**

Usually you need to fix whatever the init container is waiting on, not the init container itself. If it's waiting for a database:

```bash
kubectl get svc -n <ns>
kubectl get pods -n <ns>
kubectl get networkpolicy -n <ns>
```

If the init container command itself is wrong:

```bash
kubectl edit deployment <deploy> -n <ns>
# Fix spec.template.spec.initContainers[].command or args
```

**Verify:**

```bash
kubectl get pods -n <ns> -w
```

Wait for init container to complete (`Init:0/1` → `PodInitializing` → `Running`).

---

#### Bucket B overall stop condition

Stop Bucket B when you can clearly say: image problem, scheduling/storage problem, probe problem, resource limit problem, init container problem, or app crash/config problem.

Overall verify:

```bash
kubectl get pods -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

You are done when the pod is healthy for the right reason, not just briefly changing status.

---

<a id="bucket-c"></a>
### Bucket C: Deployment / Rollout

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** deployment readiness/rollout is the main issue.

Say: *"The deployment exists but new pods aren't appearing or the rollout seems stuck. I need to check the rollout status and ReplicaSets to see what's blocking it."*

#### Diagnose

Say: *"I'm checking the deployment and rollout state — I want to see if there are multiple ReplicaSets, which one is active, and whether the rollout is stuck or failing."*

```bash
kubectl get deploy -n <ns>
kubectl rollout status deploy/<deploy> -n <ns>
kubectl rollout history deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl describe deploy <deploy> -n <ns>
```

#### What to look for

**`kubectl get deploy -n <ns>` — READY column:** Healthy: `1/1`. Broken: `0/1` or `1/2` — available count is less than desired.

**`kubectl rollout status deploy/<deploy> -n <ns>`:** Healthy: `successfully rolled out`. Broken: `Waiting for deployment rollout to finish: 1 old replicas are pending termination` or `exceeded its progress deadline`.

**`kubectl get rs -n <ns>` — DESIRED/CURRENT/READY columns:** Healthy: one RS at `1 1 1`, older RSes at `0 0 0`. Stuck rollout: old RS `1 1 1`, new RS `1 1 0` — new pods never became Ready, old RS still serving.

**`kubectl describe deploy <deploy> -n <ns>` — Image field:** Compare `Containers: → Image:` to expected. Broken: wrong tag or nonexistent image. Also check `Conditions:` for `ProgressDeadlineExceeded`.

**`kubectl describe deploy <deploy> -n <ns>` — Selector vs Pod Template Labels:** Must match exactly. Broken: selector `app=platform-drill-api` but template labels `app=drill-api` — the Deployment cannot own any pods.

Check the new RS's pods — they usually have a clear error (ImagePullBackOff, CrashLoopBackOff, etc.). If so, go to [**Bucket B**](#bucket-b) to fix the pod issue first. If the issue is update/rollback behavior, stay here.

#### Stop condition

Stop when you can name which ReplicaSet is stuck, why its pods aren't becoming ready, and the specific field/event that confirms it.

Say: *"I've confirmed the rollout is stuck because [bad image tag / failing probes / bad config]. The new RS pods show [specific status]. I'm going to [fix the image / roll back / fix the config]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Bad image tag:** Find correct image from old running pod: `kubectl get pod <old-pod> -n <ns> -o jsonpath='{.spec.containers[0].image}'`. Fix: `kubectl set image deploy/<deploy> <container>=<correct-image>:<tag> -n <ns>`. Verify: `kubectl rollout status deploy/<deploy> -n <ns>` returns `successfully rolled out`.

**Roll back to previous revision:** `kubectl rollout undo deploy/<deploy> -n <ns>`. For specific revision: `kubectl rollout undo deploy/<deploy> -n <ns> --to-revision=<N>`. Find revision numbers: `kubectl rollout history deploy/<deploy> -n <ns>`. Verify: `kubectl rollout status` succeeds and pods are Running.

**Bad pod template config:** Fix the underlying ConfigMap/Secret/env (see [Bucket F](#bucket-f)), then `kubectl rollout restart deploy/<deploy> -n <ns>`. Verify: new pods Running and Ready, logs clean.

**Replica count wrong:** `kubectl scale deploy/<deploy> --replicas=<N> -n <ns>`. Verify: `kubectl get deploy <deploy> -n <ns>` READY shows `N/N`.

#### Verify

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl get pods -n <ns>
curl -s localhost/
```

Healthy: rollout `successfully rolled out`, one RS at desired count, all pods Running `1/1`, curl returns valid response.

---

<a id="bucket-d"></a>
### Bucket D: Service / Internal Reachability

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** app seems up but is not reachable through the service.

Say: *"Pods are Running and Ready, but I can't reach the app through the Service. I need to check if the Service is actually routing to the pods — that means checking selectors, endpoints, and ports."*

#### Diagnose

Say: *"I'm checking whether the service has endpoints — if endpoints are empty, the selector is broken. If endpoints exist but the app is unreachable, I need to check ports or NetworkPolicies."*

```bash
kubectl get svc -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get endpoints <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl get networkpolicy -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
# Then: curl -i http://localhost:8080
```

#### What to look for

**`kubectl get endpoints <svc> -n <ns>` — ENDPOINTS column:** Healthy: `10.244.x.x:8000` (one or more pod IPs). Broken: `<none>` — Service selector matches zero Ready pods. This is the single most decisive check in this bucket.

**`kubectl describe svc <svc> -n <ns>` — Selector field:** Compare exactly to `kubectl get pods -n <ns> --show-labels` LABELS column. Healthy: `Selector: app=platform-drill-api` matches pod label `app=platform-drill-api`. Broken: any character difference — `app=api` vs `app=platform-drill-api`.

**`kubectl describe svc <svc> -n <ns>` — Port and TargetPort:** Healthy: `Port: 80/TCP`, `TargetPort: 8000/TCP` where 8000 matches the container's actual listening port. Broken: `TargetPort: 8080/TCP` when container listens on 8000 — connections reach the pod but hit a closed port.

**`kubectl get pods -n <ns>` — READY column:** Only pods with `1/1` appear in endpoints. Broken: `0/1` means readiness probe failing → endpoints empty even though pod exists.

**Port-forward test:** If `kubectl port-forward svc/<svc>` + `curl` succeeds but `curl localhost/` fails → problem is Ingress or NetworkPolicy, not Service.

#### Stop condition

Say: *"I've confirmed the root cause — [empty endpoints from selector mismatch / wrong targetPort / NetworkPolicy blocking]. Endpoints are [empty/populated]. I'm going to fix [the selector / the port / the policy]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Selector mismatch (endpoints empty):** Find correct label: `kubectl get pods -n <ns> --show-labels`. Fix: `kubectl patch svc <svc> -n <ns> -p '{"spec":{"selector":{"app":"<correct-label>"}}}'`. Verify: `kubectl get endpoints <svc> -n <ns>` shows pod IPs.

**Wrong targetPort:** Find correct port: `kubectl describe pod <pod> -n <ns>` → `Containers: → Ports: → ContainerPort`. Fix: `kubectl patch svc <svc> -n <ns> -p '{"spec":{"ports":[{"port":<svc-port>,"targetPort":<correct-port>}]}}'`. Verify: `kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>` then `curl localhost:8080/` returns valid response.

**Readiness probe failing (pods not Ready → empty endpoints):** Fix the probe in [Bucket B](#bucket-b) first — once pods become Ready, endpoints auto-populate.

**NetworkPolicy blocking traffic:** Confirm by temporarily deleting suspect policy: `kubectl delete networkpolicy <policy> -n <ns>` then `curl localhost/`. If traffic works, re-apply a corrected policy. See [Bucket I](#bucket-i).

#### Verify

```bash
kubectl get endpoints <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i http://localhost:8080
curl -s localhost/
```

Healthy: endpoints populated, port-forward curl returns valid JSON, external curl works.

---

<a id="bucket-e"></a>
### Bucket E: Ingress / External Routing

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the problem is external URL / host / path routing.

Say: *"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer — something between the external URL and the Service."*

**Important rule:** if service/endpoints are broken, go back to [**Bucket D**](#bucket-d) first. Do not waste time blaming ingress when the service chain underneath is broken.

#### Diagnose

Say: *"I'm checking the Ingress resource — I want to see if it has an address assigned, whether the backend service name and port match what actually exists, and whether the IngressClass is correct."*

```bash
kubectl get ingress -n <ns>
kubectl describe ingress <ing> -n <ns>
kubectl get svc -n <ns>
kubectl get endpoints <svc> -n <ns>
curl -H "Host: <host>" -i http://<ingress-ip>
```

#### What to look for

**`kubectl get ingress -n <ns>` — ADDRESS column:** Healthy: an IP or hostname (e.g. `localhost`). Broken: blank — ingress controller hasn't admitted this resource (wrong IngressClass or controller not running).

**`kubectl describe ingress <ing> -n <ns>` — IngressClass:** Healthy: `nginx` (or matching installed controller). Broken: empty, `<none>`, or wrong class name. Find correct class: `kubectl get ingressclass`.

**`kubectl describe ingress <ing> -n <ns>` — Rules > Backends:** Healthy: `<svc>:80` with populated endpoints shown inline. Broken: wrong service name (compare to `kubectl get svc -n <ns>`), or wrong port — the Ingress must reference the Service's `port:` (not `targetPort`).

**`kubectl describe ingress <ing> -n <ns>` — Host and Path:** If `Host:` is set, requests need a matching Host header. Broken: host `api.example.com` but you're curling `localhost`. Path `pathType: Exact` with `/api` won't match `/`.

**`kubectl get pods -n ingress-nginx` — controller health:** Healthy: `Running` and `1/1`. Broken: `CrashLoopBackOff` or absent — no controller = no address on any Ingress.

#### Stop condition

Say: *"I've confirmed the root cause — [wrong backend port / wrong service name / missing IngressClass / controller down]. I can see it in [describe ingress Backends field / ADDRESS column]. The underlying service has healthy endpoints, so fixing the Ingress should restore access."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Wrong backend port:** Find correct port from `kubectl get svc <svc> -n <ns>` PORT(S) column. Fix: `kubectl patch ingress <ing> -n <ns> --type=json -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":<correct-port>}]'`. Verify: `curl -s localhost/` returns valid response.

**Wrong backend service name:** Find correct name from `kubectl get svc -n <ns>`. Fix: `kubectl patch ingress <ing> -n <ns> --type=json -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"<correct-svc>"}]'`. Verify: `kubectl describe ingress <ing> -n <ns>` shows populated endpoints under Backends.

**Wrong IngressClass (no address):** Find correct class: `kubectl get ingressclass`. Fix: `kubectl patch ingress <ing> -n <ns> -p '{"spec":{"ingressClassName":"nginx"}}'`. Verify: `kubectl get ingress -n <ns>` ADDRESS populates within seconds.

**Controller not running:** Fix controller first: `kubectl get pods -n ingress-nginx`, then `kubectl rollout restart deploy/ingress-nginx-controller -n ingress-nginx`. Verify: controller Running and `1/1`, then re-check `kubectl get ingress -n <ns>` for ADDRESS.

**Service underneath is broken:** Stop — go to [Bucket D](#bucket-d). Don't edit Ingress when the problem is below it.

#### Verify

```bash
kubectl get ingress -n <ns>
kubectl describe ingress <ing> -n <ns>
curl -s localhost/
curl -s localhost/health
curl -s localhost/items
```

Healthy: ADDRESS populated, Backends show correct service with endpoints, all three curl responses return valid JSON.

---

<a id="bucket-f"></a>
### Bucket F: Config / Secret / Volume / Dependency Setup

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the app is failing due to setup/configuration rather than routing.

Say: *"I see the pod is failing because of configuration. This could be a missing ConfigMap or Secret, a wrong reference name, or a correct reference with a wrong value inside. I need to check what the pod is referencing and whether the actual values match what the app expects."*

#### Diagnose

Say: *"I'm checking whether the pod can resolve all its config — configmaps, secrets, and volume mounts. I want to see if Kubernetes is reporting missing references before I look at app logs."*

```bash
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o yaml
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A2 -E 'configMapRef|secretRef'
```

#### What to look for

**`kubectl describe pod <pod> -n <ns>` — Events section:** Healthy: no warnings about missing objects. Broken: `Warning  Failed  ... Error: configmap "<cm>" not found` or `secret "<secret>" not found`. The event names the exact missing resource.

**`kubectl describe pod <pod> -n <ns>` — Environment block:** Each env var sourced from a ConfigMap/Secret shows the source name. Compare to `kubectl get configmap -n <ns>` / `kubectl get secret -n <ns>` — names must match character-for-character.

**`kubectl get pod <pod> -n <ns> -o yaml` — `envFrom[].configMapRef.name` and `secretRef.name`:** Healthy: names match existing objects. Broken: typo (e.g., `app-configs` vs `app-config`).

**`kubectl get configmap <cm> -n <ns> -o yaml` — `data` block:** Healthy: key names and values match what app expects (e.g., `POSTGRES_HOST: postgres`). Broken: value is wrong (e.g., `POSTGRES_DB: platformdrill_v2` when DB is `platformdrill`). App logs typically print the bad value — cross-reference.

**`kubectl get secret <secret> -n <ns> -o yaml` — `data` block (base64-encoded):** Decode with `echo "<value>" | base64 -d`. Healthy: decoded value matches expected credential. Broken: wrong password, or value was double-encoded.

**`kubectl logs <pod> -n <ns>`:** Look for `KeyError`, `undefined variable`, `could not parse config`, connection/auth failures. These point to which specific key or value is wrong.

#### Stop condition

Say: *"The root cause is [missing ConfigMap / wrong reference name / wrong value in key X]. I can see it in [Events / ConfigMap data / app logs]. I'm going to [create the missing resource / fix the reference / correct the value]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Missing ConfigMap or Secret (event says "not found"):** Find the expected name from `kubectl get deploy <deploy> -n <ns> -o yaml | grep configMapRef`. Create: `kubectl create configmap <cm> --from-literal=<key>=<value> -n <ns>` or `kubectl create secret generic <secret> --from-literal=<key>=<value> -n <ns>`. Verify: `kubectl describe pod <pod> -n <ns>` — no more "not found" events.

**Wrong reference name in Deployment:** Find correct name: `kubectl get configmap -n <ns>`. Fix: `kubectl edit deploy <deploy> -n <ns>` — correct `envFrom[].configMapRef.name` or `secretRef.name`. Verify: new pod starts without config errors.

**Wrong value in ConfigMap:** Find correct value by cross-referencing (e.g., `kubectl get svc -n <ns>` for hostname, or the Postgres ConfigMap for DB name). Fix: `kubectl edit configmap <cm> -n <ns>`, then `kubectl rollout restart deploy/<deploy> -n <ns>` (pods don't auto-reload). Verify: `kubectl exec <pod> -n <ns> -- env | grep <KEY>` shows correct value; `curl localhost/health` returns 200.

**Wrong value in Secret:** Decode current: `kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d`. Fix: `kubectl edit secret <secret> -n <ns>` (values must be base64-encoded). Then `kubectl rollout restart deploy/<deploy> -n <ns>`. Verify: app logs show no auth failure.

**Wrong volume mount path:** Find correct path from app documentation or image defaults. Fix: `kubectl edit deploy <deploy> -n <ns>` — correct `volumeMounts[].mountPath`. Verify: `kubectl exec <pod> -n <ns> -- ls <correct-path>` shows expected files.

#### Verify

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl describe pod <pod> -n <ns>          # no Warning events
kubectl exec <pod> -n <ns> -- env | grep <KEY>   # correct values
kubectl logs <pod> -n <ns>                  # clean startup
curl -s localhost/health                    # 200
```

---

<a id="bucket-g"></a>
### Bucket G: Jobs / CronJobs

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the scenario is batch/scheduled work.

Say: *"This is a Job or CronJob issue. I need to check whether the job itself is misconfigured, or if the pods it creates are failing."*

#### Diagnose

Say: *"I'm checking the Job or CronJob status — I want to see completions vs desired, whether any pods failed, and what the pod logs say."*

```bash
kubectl get jobs -n <ns>
kubectl get cronjobs -n <ns>
kubectl describe job <job> -n <ns>
kubectl describe cronjob <cj> -n <ns>
kubectl get pods -n <ns> --selector=job-name=<job>
kubectl logs <job-pod> -n <ns>
```

#### What to look for

**`kubectl get jobs -n <ns>` — COMPLETIONS column:** Healthy: `1/1`. Broken: `0/1` after sufficient time — pod is failing or never started.

**`kubectl describe job <job> -n <ns>` — Events section:** Healthy: no `BackoffLimitExceeded`. Broken: `Warning BackoffLimitExceeded Job has reached the specified backoff limit` — Job will not retry further.

**`kubectl get pods --selector=job-name=<job> -n <ns>` — STATUS:** Healthy: `Completed`. Broken: `Error`, `OOMKilled`, `CrashLoopBackOff`. Use `kubectl logs <pod> --previous` for crash output.

**`kubectl get cronjobs -n <ns>` — SUSPEND and LAST SCHEDULE columns:** Healthy: `SUSPEND: False`, `LAST SCHEDULE` recent. Broken: `SUSPEND: True` (paused, won't fire), or `LAST SCHEDULE: <none>` (bad schedule syntax — never fires).

**`kubectl describe cronjob <cj> -n <ns>` — Schedule field:** Healthy: valid 5-field cron (e.g., `*/5 * * * *`). Broken: only 4 fields, or invalid syntax — Kubernetes accepts it silently but never fires.

**`kubectl describe cronjob <cj> -n <ns>` — Active count:** If high and not decreasing, a `concurrencyPolicy: Forbid` or `Allow` may be causing stale runs to pile up.

#### Stop condition

Say: *"The root cause is [backoffLimit reached / CronJob suspended / bad schedule syntax / pod failing with specific error]. I'm going to [fix the underlying pod issue and recreate the Job / unsuspend / fix the schedule]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix. Jobs are immutable after creation — you must delete and recreate to change the spec.

**Pod failing (image/command/config):** Fix the root cause ([Bucket B](#bucket-b) or [Bucket F](#bucket-f)), then recreate: `kubectl delete job <job> -n <ns> && kubectl apply -f <job-manifest>.yaml`. Verify: `kubectl get jobs -n <ns>` shows `1/1`.

**BackoffLimit reached:** Delete and recreate after fixing root cause: `kubectl delete job <job> -n <ns> && kubectl apply -f <job-manifest>.yaml`. Verify: new pod reaches `Completed`.

**CronJob suspended:** Fix: `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"suspend":false}}'`. Verify: `kubectl get cronjobs -n <ns>` SUSPEND shows `False`. Test immediately: `kubectl create job <job>-test --from=cronjob/<cj> -n <ns>`.

**Bad schedule syntax:** Find correct expression (validate at crontab.guru). Fix: `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"schedule":"<correct-cron>"}}'`. Verify: manually trigger `kubectl create job <job>-test --from=cronjob/<cj> -n <ns>` and confirm completion.

**Stale active Job blocking new runs:** Delete stale Job: `kubectl delete job <stale-job> -n <ns>`. Verify: next scheduled run creates a new Job.

#### Verify

```bash
kubectl get jobs -n <ns>                              # COMPLETIONS 1/1
kubectl get pods --selector=job-name=<job> -n <ns>    # Completed
kubectl logs <job-pod> -n <ns>                        # clean exit
```

---

<a id="bucket-h"></a>
### Bucket H: Application-Level Failures

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** pods are Running and Ready, endpoints are populated, but the app returns 5xx errors or wrong responses. Kubernetes thinks everything is fine.

Say: *"Everything looks healthy from a Kubernetes perspective — pods are Running, Ready, endpoints are populated. So this is an application-level issue. Logs should tell me what's going on."*

#### Diagnose

Say: *"Pods are running and Kubernetes looks healthy — no probe failures, endpoints populated. This is an application-level problem. I'm going to read the logs first, then cross-reference the config the app is actually using."*

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl exec <pod> -n <ns> -- env | sort
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
```

#### What to look for

| Log message | Cause | How to diagnose | How to find correct value |
|---|---|---|---|
| `connection refused` to DB host | Wrong hostname or DB not running | `kubectl exec <pod> -- env \| grep POSTGRES_HOST`; `kubectl get svc -n <ns>` — compare names | Service NAME column = correct hostname |
| `password authentication failed` | Wrong credentials | `kubectl get secret <secret> -n <ns> -o jsonpath='{.data.POSTGRES_PASSWORD}' \| base64 -d` | Compare to authoritative Secret (e.g., postgres-secret) |
| `database "X" does not exist` | Wrong DB name in config | `kubectl exec <pod> -- env \| grep POSTGRES_DB`; `kubectl get configmap <cm> -n <ns> -o yaml` | Compare to Postgres ConfigMap's `POSTGRES_DB` |
| `relation "X" does not exist` | Schema not initialized | Check logs for migration output; check if init Job completed | App may need clean restart after fixing config |
| `Name or service not known` | DNS can't resolve hostname | `kubectl exec <pod> -- nslookup <hostname>` | `kubectl get svc -n <ns>` — use exact Service name |
| `ECONNREFUSED` | Wrong port or target service down | `kubectl exec <pod> -- env \| grep POSTGRES_PORT`; `kubectl get endpoints <svc> -n <ns>` | Service port from `kubectl describe svc` |

#### Stop condition

Say: *"The app is failing because `<env-var>` is set to `<wrong-value>` but the actual [service/database/credential] expects `<correct-value>`. I'm going to fix the [ConfigMap/Secret] and restart."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Wrong ConfigMap value (hostname, DB name, port, user):** Find correct value by cross-referencing (`kubectl get svc -n <ns>` for hostname, Postgres ConfigMap for DB name). Fix: `kubectl edit configmap <cm> -n <ns>`, then `kubectl rollout restart deploy/<deploy> -n <ns>`. Verify: `kubectl exec <pod> -n <ns> -- env | grep <KEY>` shows correct value; `curl localhost/health` returns 200.

**Wrong Secret value (password, credentials):** Decode current: `kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d`. Find correct value from authoritative source. Fix: `kubectl edit secret <secret> -n <ns>` (values must be base64-encoded), then `kubectl rollout restart deploy/<deploy> -n <ns>`. Verify: app logs show clean connection.

**Schema not initialized:** If app runs migrations on startup, it may need a clean restart after fixing config: `kubectl rollout restart deploy/<deploy> -n <ns>`. Watch logs: `kubectl logs -f <pod> -n <ns>` for table creation output.

#### Verify

```bash
kubectl logs <pod> -n <ns>                   # no connection or auth errors
kubectl exec <pod> -n <ns> -- env | sort     # env vars correct
curl -s localhost/health                     # 200
curl -s localhost/items                      # expected data
```

---

<a id="bucket-i"></a>
### Bucket I: Network Policies

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** everything looks correct — pods Running, Ready, endpoints populated, services exist — but traffic silently fails or times out. No error messages, just no response.

Say: *"Everything looks healthy but traffic is failing silently. When all the obvious things check out, it's often a NetworkPolicy blocking traffic. Let me check."*

#### Diagnose

Say: *"Everything looks healthy but traffic is failing silently. My working theory is a NetworkPolicy blocking legitimate traffic. Let me map all policies in this namespace."*

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
```

#### What to look for

**`kubectl get networkpolicy -n <ns>` — POD-SELECTOR column:** Shows which pods each policy targets. `<none>` means empty `podSelector: {}` — applies to ALL pods. Compare each selector value to actual pod labels with `kubectl get pods -n <ns> --show-labels`.

**`kubectl describe networkpolicy <policy> -n <ns>` — Policy Types, Ingress/Egress rules:**

- If `Policy Types: Ingress` is listed, any inbound traffic not explicitly allowed is **denied**
- If `Policy Types: Egress` is listed, any outbound traffic not explicitly allowed is **denied**
- Healthy: a default-deny exists AND matching allow rules exist for all legitimate traffic flows
- Broken: default-deny exists but allow rule has wrong `podSelector` (e.g., `app: platform-drill-api-v2` when pods have `app: platform-drill-api`) — the allow matches nothing, deny blocks everything

**Common broken patterns:**
- Allow rule `podSelector` label doesn't match any running pods — check character-for-character against `kubectl get pods --show-labels`
- Allow rule `namespaceSelector` wrong — for ingress-nginx traffic, need `kubernetes.io/metadata.name: ingress-nginx`; find with `kubectl get ns ingress-nginx --show-labels`
- Allow rule missing port spec — some CNIs require explicit port even when podSelector is correct
- No DNS egress rule — pods can't resolve hostnames; produces silent connection failures that look like networking issues

#### Stop condition

Say: *"Traffic was being dropped by `<policy-name>`. The allow rule [was missing / had a wrong podSelector]. I'm going to [create the missing allow / fix the selector] rather than leave the namespace unprotected."*

#### Quick test — temporarily remove policies

Delete one at a time and test after each — do NOT delete all at once:

```bash
kubectl get networkpolicy -n <ns> -o name
kubectl delete networkpolicy <policy-name> -n <ns>
curl http://localhost/
```

If traffic works after deleting a specific policy, that was the blocker.

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Wrong podSelector in allow rule:** Find correct labels: `kubectl get pods -n <ns> --show-labels`. Fix: `kubectl edit networkpolicy <policy> -n <ns>` — correct `podSelector.matchLabels` to match actual pod labels. Verify: `curl -s localhost/` returns valid response.

**Missing allow rule for app-to-database egress:** Find app and DB labels from `kubectl get pods -n <ns> --show-labels`.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-postgres
  namespace: <ns>
spec:
  podSelector:
    matchLabels:
      app: <app-label>
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: <db-label>
      ports:
        - protocol: TCP
          port: 5432
EOF
```

**Missing DNS egress rule:** Find kube-system namespace label: `kubectl get ns kube-system --show-labels`.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

**Fix an existing policy:**

```bash
kubectl edit networkpolicy <policy-name> -n <ns>
```

#### Verify

```bash
kubectl get networkpolicy -n <ns>
curl -s localhost/
curl -s localhost/health
curl -s localhost/items
```

All policies present, all curl responses return expected data.

---

<a id="bucket-j"></a>
### Bucket J: Storage

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** a PVC is stuck in Pending, or a pod can't start because of a volume issue.

Say: *"I see a PVC stuck in Pending. That means it can't bind to a PersistentVolume. I need to check if there's a matching StorageClass and if the request is valid."*

#### Diagnose

Say: *"The pod is Pending or failing to start with a volume error. I need to check whether the PVC can bind — that means checking StorageClass, capacity, and access mode."*

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv
kubectl get storageclass
kubectl describe pod <pod> -n <ns>
```

#### What to look for

**`kubectl get pvc -n <ns>` — STATUS column:** Healthy: `Bound`. Broken: `Pending` — no PV has matched; pod will not schedule until resolved.

**`kubectl describe pvc <pvc> -n <ns>` — Events section:** The event message names the exact failure:

| Event message | Cause | How to confirm |
|---|---|---|
| `no persistent volumes available` | No matching PV or StorageClass | `kubectl get storageclass` — check if PVC's `storageClassName` exists |
| `storageclass "X" not found` | PVC references nonexistent StorageClass | `kubectl get storageclass` — compare names exactly |
| Capacity mismatch | PV too small for PVC request | `kubectl describe pvc` Capacity vs `kubectl describe pv` Capacity |
| Access mode mismatch | PVC requests `ReadWriteMany`, PV offers `ReadWriteOnce` | Compare `Access Modes` in both `describe pvc` and `describe pv` |
| PV already bound | PV claimed by different PVC | `kubectl get pv` — STATUS `Bound`, CLAIM column shows different PVC |

**`kubectl describe pod <pod> -n <ns>` — Mounts section:** Check `volumeMounts[].mountPath`. Broken: mount path is `/data` but app expects `/var/lib/postgresql/data`.

#### Stop condition

Say: *"The PVC is Pending because [wrong StorageClass / capacity mismatch / access mode mismatch]. I can see it in the PVC events. I'm going to recreate the PVC with the correct spec."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix. PVC fields are mostly immutable — you must delete and recreate.

**Wrong StorageClass:** Find available classes: `kubectl get storageclass`. Delete and recreate:

```bash
kubectl delete pvc <pvc> -n <ns>
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <pvc>
  namespace: <ns>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: <correct-class>
  resources:
    requests:
      storage: 1Gi
EOF
```

Verify: `kubectl get pvc <pvc> -n <ns>` shows `Bound`.

**Wrong volume mount path:** Find correct path from app documentation or image defaults. Fix: `kubectl edit deploy <deploy> -n <ns>` — correct `volumeMounts[].mountPath`. Verify: `kubectl logs <pod> -n <ns>` — no data directory errors.

**Pod still Pending after PVC fix:** `kubectl rollout restart deploy/<deploy> -n <ns>` to force new pod creation. Verify: pod moves to Running.

#### Verify

```bash
kubectl get pvc -n <ns>              # Bound
kubectl get pods -n <ns>             # Running, Ready
curl -s localhost/health             # 200
```

---

<a id="bucket-k"></a>
### Bucket K: Namespace Confusion

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** resources appear to be missing entirely — you expect pods, services, or other objects but they don't show up.

Say: *"I'm not seeing the resources I expect. Let me check if they're deployed to a different namespace."*

#### Diagnose

Say: *"Resources appear to be missing. Before I assume they don't exist, I want to check whether they were deployed to the wrong namespace — this is a quick check that rules out a whole class of problems."*

```bash
kubectl get all -A
kubectl get ns
kubectl config view --minify | grep namespace
```

#### What to look for

**`kubectl get all -A` — NAMESPACE column:** Scan for your expected resources. Healthy: all app resources in the expected namespace. Broken: resources in `default` or a similarly-named but wrong namespace (e.g., `drill-app` vs `drill`).

**`kubectl get ns` — NAME column:** Healthy: one namespace matches. Broken: two similar names exist and resources are split between them.

**`kubectl config view --minify | grep namespace`:** Healthy: shows your target namespace. Broken: shows `default` or a wrong namespace — every `kubectl` command without `-n` has been targeting the wrong place.

#### Stop condition

Say: *"The resources exist — they're in `<actual-ns>`, not `<expected-ns>`. That explains why my earlier commands returned nothing. I'm going to [move them / fix the default namespace]."*

#### Fix patterns

Change one thing at a time. Verify after each change before moving to the next fix.

**Wrong default namespace:** Fix: `kubectl config set-context --current --namespace=<correct-ns>`. Verify: `kubectl config view --minify | grep namespace` shows correct value; `kubectl get all` returns expected resources.

**Resources in wrong namespace:** Export, fix, and re-apply:

```bash
kubectl get <resource> <name> -n <wrong-ns> -o yaml > fix.yaml
# Edit fix.yaml: change metadata.namespace to <correct-ns>
kubectl apply -f fix.yaml
kubectl delete <resource> <name> -n <wrong-ns>
```

Verify: `kubectl get all -n <correct-ns>` shows the moved resources.

**Cross-namespace service reference needed:** If app in one namespace needs to reach a service in another, use FQDN: `<service-name>.<namespace>.svc.cluster.local`. Update the relevant ConfigMap hostname accordingly.

#### Verify

```bash
kubectl get all -n <correct-ns>
kubectl get endpoints -n <correct-ns>
curl -s localhost/
curl -s localhost/health
```

---

<a id="quick-reference"></a>
## Quick Reference — Most Useful Commands

```bash
# Broad view
kubectl get all -n <ns>
kubectl get all -A
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp

# Pod diagnostics
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -c <container> -n <ns>
kubectl exec <pod> -n <ns> -- env | sort

# Service diagnostics
kubectl describe svc <svc> -n <ns>
kubectl get endpoints <svc> -n <ns>
kubectl get pods -n <ns> --show-labels

# Config diagnostics
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# Deployment diagnostics
kubectl rollout status deployment/<deploy> -n <ns>
kubectl rollout history deployment/<deploy> -n <ns>
kubectl get rs -n <ns>

# Network policy diagnostics
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>

# Storage diagnostics
kubectl get pvc -n <ns>
kubectl get pv
kubectl get storageclass

# RBAC diagnostics
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
kubectl get sa,role,rolebinding -n <ns>

# Quick fixes
kubectl edit deployment <deploy> -n <ns>
kubectl edit svc <svc> -n <ns>
kubectl edit configmap <cm> -n <ns>
kubectl set image deployment/<deploy> <container>=<image>:<tag> -n <ns>
kubectl rollout restart deployment/<deploy> -n <ns>
kubectl rollout undo deployment/<deploy> -n <ns>

# Testing
kubectl port-forward svc/<svc> 8080:<port> -n <ns>
kubectl exec <pod> -n <ns> -- curl -s http://localhost:<port><path>
```

---

<a id="process-summary"></a>
## The Process (Summary)

1. Apply [Rule 0](#rule-0) — do not guess
2. Run [orient and triage](#phase-1-orient-and-triage) or the [Fast Path](#phase-1-orient-and-triage)
3. Identify strongest signal using the [Quick Signal Table](#quick-signal-table)
4. Commit to one bucket — say why out loud
5. Run that bucket's diagnostic commands
6. Stop when root cause is clear — say what you found and your fix plan
7. Apply the smallest fix — change one thing at a time, verify after each change
8. Verify the fix worked (bucket-specific check, then end-to-end curl)

---

<a id="appendix-linux"></a>
## Appendix A: Linux / Bash / Zsh Commands

---

| Command | What it does | Example |
|---|---|---|
| `grep "pattern" file` | Search for pattern in file | `grep "error" app.log` |
| `grep -r "pattern" dir/` | Recursive search in directory | `grep -r "POSTGRES" ./manifests/` |
| `grep -i "pattern" file` | Case-insensitive search | `grep -i "crashloop" events.txt` |
| `grep -c "pattern" file` | Count matching lines | `grep -c "200" access.log` |
| `cat file` | Print file contents | `cat /etc/resolv.conf` |
| `less file` | Page through file (q to quit) | `less app.log` |
| `head -n 20 file` | Print first N lines | `head -n 20 startup.log` |
| `tail -n 50 file` | Print last N lines | `tail -n 50 app.log` |
| `tail -f file` | Follow file in real time | `tail -f <ns>-session.log` |
| `wc -l file` | Count lines in file | `wc -l app.log` |
| `awk '{print $3}' file` | Print Nth column | `kubectl get pods \| awk '{print $1}'` |
| `cut -d',' -f2 file` | Cut field by delimiter | `cut -d':' -f2 /etc/passwd` |
| `sort file` | Sort lines alphabetically | `sort namespaces.txt` |
| `uniq file` | Remove consecutive duplicates | `sort errors.txt \| uniq` |
| `sort \| uniq -c` | Count occurrences of each unique line | `cat events.txt \| sort \| uniq -c` |
| `xargs` | Pass stdin as arguments to a command | `kubectl get pods \| awk '{print $1}' \| xargs kubectl describe pod` |
| `watch -n 2 cmd` | Re-run command every N seconds | `watch -n 2 kubectl get pods -n <ns>` |
| `env` | Print all environment variables | `env \| grep POSTGRES` |
| `export VAR=val` | Set env var for current session | `export KUBECONFIG=~/.kube/config` |
| `echo "string"` | Print string to stdout | `echo $POSTGRES_HOST` |
| `curl -s URL` | Silent HTTP request (no progress) | `curl -s localhost/health` |
| `curl -o /dev/null -w '%{http_code}' URL` | Print only HTTP status code | `curl -s -o /dev/null -w '%{http_code}' localhost/` |
| `curl -H "Header: val" URL` | Send custom header | `curl -H "Host: myapp.local" localhost/health` |
| `curl --max-time 5 URL` | Fail after N seconds | `curl --max-time 5 localhost/health` |
| `curl -i URL` | Include response headers in output | `curl -i localhost/health` |
| `wget -qO- URL` | Fetch URL to stdout, quiet | `wget -qO- localhost/health` |
| `jq '.key'` | Extract key from JSON | `kubectl get pod app -o json \| jq '.status.phase'` |
| `jq -r '.key'` | Raw string output (no quotes) | `kubectl get secret s -o json \| jq -r '.data.password'` |
| `base64 -d <<< "string"` | Decode base64 (Linux) | `echo "cGFzcw==" \| base64 -d` |
| `base64 -D <<< "string"` | Decode base64 (macOS) | `echo "cGFzcw==" \| base64 -D` |
| `nc -z host port` | Test TCP reachability (no data) | `nc -z postgres 5432` |
| `dig hostname` | DNS lookup with full response | `dig postgres.<ns>.svc.cluster.local` |
| `nslookup hostname` | Simple DNS lookup | `nslookup postgres` |
| `ps aux` | List all running processes | `ps aux \| grep python` |
| `kill -9 PID` | Force-kill process by PID | `kill -9 1234` |

---

<a id="appendix-kubectl"></a>
## Appendix B: kubectl Commands

---

| Command | Purpose |
|---|---|
| **Read** | |
| `kubectl config current-context` | Show active cluster context |
| `kubectl config use-context <ctx>` | Switch cluster context |
| `kubectl config view --minify` | Show active context config only |
| `kubectl config set-context --current --namespace=<ns>` | Set default namespace |
| `kubectl get ns` | List all namespaces |
| `kubectl get all -n <ns>` | List pods, deploys, services, replicasets in namespace |
| `kubectl get all -A` | List all resources across all namespaces |
| `kubectl get pods -n <ns> -o wide` | Pods with node and IP info |
| `kubectl get pods -n <ns> --show-labels` | Pods with their labels |
| `kubectl get pods -n <ns> -w` | Watch pod status in real time |
| `kubectl get deploy -n <ns>` | List Deployments |
| `kubectl get svc -n <ns>` | List Services |
| `kubectl get endpoints -n <ns>` | List Endpoints (check if populated) |
| `kubectl get ingress -n <ns>` | List Ingress resources |
| `kubectl get pvc -n <ns>` | List PersistentVolumeClaims |
| `kubectl get pv` | List PersistentVolumes (cluster-scoped) |
| `kubectl get sc` | List StorageClasses |
| `kubectl get configmap -n <ns>` | List ConfigMaps |
| `kubectl get secret -n <ns>` | List Secrets |
| `kubectl get networkpolicy -n <ns>` | List NetworkPolicies |
| `kubectl get sa -n <ns>` | List ServiceAccounts |
| `kubectl get role,rolebinding -n <ns>` | List RBAC Role and RoleBinding |
| `kubectl get rs -n <ns>` | List ReplicaSets |
| `kubectl get jobs -n <ns>` | List Jobs |
| `kubectl get cronjobs -n <ns>` | List CronJobs |
| `kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp` | Events sorted by time |
| `kubectl get pod <pod> -n <ns> -o yaml` | Full pod spec as YAML |
| `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[*].image}'` | Extract specific field via jsonpath |
| `kubectl api-resources` | List all resource types and short names |
| `kubectl explain pod.spec.containers` | Show schema docs for a resource field |
| **Diagnose** | |
| `kubectl describe pod <pod> -n <ns>` | Full pod state, events, probe status |
| `kubectl describe svc <svc> -n <ns>` | Service selector, endpoints, ports |
| `kubectl describe deploy <deploy> -n <ns>` | Deployment state, strategy, conditions |
| `kubectl describe ingress <ingress> -n <ns>` | Ingress rules, backend, address |
| `kubectl describe pvc <pvc> -n <ns>` | PVC binding status and events |
| `kubectl describe node <node>` | Node capacity, allocatable, taints, conditions |
| `kubectl logs <pod> -n <ns>` | Container stdout/stderr |
| `kubectl logs <pod> -n <ns> --previous` | Logs from last crashed container |
| `kubectl logs <pod> -n <ns> -c <container>` | Logs from specific container (init containers) |
| `kubectl logs <pod> -n <ns> --tail=50` | Last 50 lines of logs |
| `kubectl logs <pod> -n <ns> -f` | Stream logs in real time |
| `kubectl top nodes` | Node CPU/memory usage |
| `kubectl top pods -n <ns>` | Pod CPU/memory usage |
| `kubectl auth can-i <verb> <resource> -n <ns> --as=system:serviceaccount:<ns>:<sa>` | Check RBAC permission for a ServiceAccount |
| `kubectl rollout status deploy/<deploy> -n <ns>` | Show rollout progress |
| `kubectl rollout history deploy/<deploy> -n <ns>` | List rollout revision history |
| **Fix** | |
| `kubectl apply -f <file>` | Apply manifest (create or update) |
| `kubectl edit <resource> <name> -n <ns>` | Edit resource live in $EDITOR |
| `kubectl patch <resource> <name> -n <ns> -p '<json>'` | Inline patch resource |
| `kubectl set image deploy/<deploy> <container>=<image> -n <ns>` | Update container image |
| `kubectl rollout undo deploy/<deploy> -n <ns>` | Roll back to previous revision |
| `kubectl rollout restart deploy/<deploy> -n <ns>` | Restart all pods in a deployment |
| `kubectl scale deploy/<deploy> --replicas=<n> -n <ns>` | Change replica count |
| `kubectl delete pod <pod> -n <ns>` | Force pod recreation |
| `kubectl delete <resource> <name> -n <ns>` | Delete any resource |
| `kubectl create configmap <name> --from-literal=KEY=val -n <ns>` | Create ConfigMap from literals |
| `kubectl create secret generic <name> --from-literal=KEY=val -n <ns>` | Create Secret from literals |
| `kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa> -n <ns>` | Create RoleBinding |
| `kubectl create job <name> --from=cronjob/<cj> -n <ns>` | Trigger CronJob manually |
| **Debug/Test** | |
| `kubectl exec <pod> -n <ns> -- env` | Print env vars inside container |
| `kubectl exec -it <pod> -n <ns> -- sh` | Interactive shell in container |
| `kubectl exec <pod> -n <ns> -- wget -qO- http://svc/health` | Test HTTP from inside the cluster |
| `kubectl exec <pod> -n <ns> -- nc -z <host> <port>` | Test TCP reachability from inside pod |
| `kubectl port-forward pod/<pod> 8080:8000 -n <ns>` | Forward pod port to localhost |
| `kubectl port-forward svc/<svc> 8080:80 -n <ns>` | Forward service port to localhost |

---

<a id="appendix-git"></a>
## Appendix C: Git Commands

---

| Command | Purpose |
|---|---|
| `git status` | Show changed, staged, and untracked files |
| `git diff` | Show unstaged changes |
| `git diff --staged` | Show staged changes (what will be committed) |
| `git log --oneline` | Compact commit history |
| `git log -p` | Commit history with diffs |
| `git checkout <branch>` | Switch to existing branch |
| `git checkout -b <branch>` | Create and switch to new branch |
| `git add <file>` | Stage specific file |
| `git commit -m "message"` | Commit staged changes |
| `git commit --amend` | Amend most recent commit |
| `git stash` | Temporarily shelve uncommitted changes |
| `git stash pop` | Restore most recently stashed changes |
| `git reset --soft HEAD~1` | Undo last commit, keep changes staged |
| `git reset --hard HEAD~1` | **Destructive.** Undo last commit and discard all changes |
| `git branch` | List local branches |
| `git branch -d <branch>` | Delete merged local branch |
| `git cherry-pick <sha>` | Apply a specific commit to current branch |
| `git blame <file>` | Show who last changed each line |

---

<a id="appendix-http"></a>
## Appendix D: HTTP Status Codes

---

| Code | Meaning | Kubernetes / Interview Context |
|---|---|---|
| 200 | OK | Expected response from healthy endpoints (`/health`, `/`, `/items`). |
| 301 | Moved Permanently | Permanent redirect. May appear from nginx Ingress path rewrites. |
| 302 | Found (Temporary Redirect) | Temporary redirect. Check Ingress path rules or app-level redirects. |
| 400 | Bad Request | Malformed request. Usually app-level — check request format, not K8s config. |
| 401 | Unauthorized | Authentication missing or invalid. Check auth headers, tokens, or ServiceAccount. |
| 403 | Forbidden | Authenticated but not permitted. Check RBAC Role/RoleBinding, `kubectl auth can-i`. |
| 404 | Not Found | Route doesn't exist. Check Ingress path rules, backend service name, app routes. |
| 408 | Request Timeout | Client timed out waiting. Check app logs, Ingress timeout config. |
| 429 | Too Many Requests | Rate limited. Check Ingress rate-limit annotations or API gateway config. |
| 500 | Internal Server Error | App crashed processing request. Check pod logs for stack trace. |
| 502 | Bad Gateway | Proxy received invalid response from upstream. Check endpoints, pod readiness, targetPort. |
| 503 | Service Unavailable | No healthy backend. From nginx Ingress: check pod readiness, service selector, endpoints, backend port. |
| 504 | Gateway Timeout | Proxy timed out waiting for upstream. Check app performance, resource limits, Ingress timeout settings. |

---

<a id="appendix-exit-codes"></a>
## Appendix E: Exit Codes, Pod Statuses, and Error Reasons

---

### Container Exit Codes

| Code | Meaning | Typical Cause | Next Step |
|---|---|---|---|
| 0 | Success | Container completed normally | Expected for init containers and Jobs. If unexpected for a long-running app, check command/args. |
| 1 | Generic application error | Unhandled exception, config error, bad startup | `kubectl logs <pod> --previous` |
| 2 | Misuse of shell builtins | Bad shell command in `command` or `args` | Check pod spec `command`/`args` syntax |
| 3 | Application-defined exit | App uses code 3 for specific error (e.g., Python/uvicorn unhandled exception) | Check app logs |
| 126 | Command not executable | Script/binary not executable | Check file permissions inside the image |
| 127 | Command not found | Binary missing from container image | Verify image contents with `kubectl exec` |
| 128 | Invalid argument to exit | Shell received signal or invalid exit call | Check entrypoint/cmd scripting |
| 137 | OOMKilled (128 + 9) | Container exceeded memory limit | `kubectl describe pod` last state; increase memory limit |
| 139 | Segfault (128 + 11) | Memory access violation | Application bug or corrupted binary |
| 143 | Graceful SIGTERM (128 + 15) | Normal shutdown, preStop hook, or pod deletion | Usually expected. If unexpected, check liveness probe. |

---

### Pod Status Reasons

| Status | Meaning | Next Step |
|---|---|---|
| Running | Containers started, at least one still running | Check Ready column — Running but 0/1 means readiness probe failing |
| Pending | Pod accepted but not scheduled or containers not started | `kubectl describe pod` — look for FailedScheduling (resources, taints, PVC) |
| CrashLoopBackOff | Container keeps crashing, K8s backing off restarts | `kubectl logs <pod> --previous` for last crash output |
| ImagePullBackOff | Repeated image pull failures | `kubectl describe pod` — check image name/tag, registry, pull secrets |
| ErrImagePull | One-time image pull failure | Same as above — check Events for specific error |
| OOMKilled | Container exceeded memory limit | Increase memory limit or reduce usage; `kubectl describe pod` last state |
| Error | Container exited with non-zero code | `kubectl logs <pod> --previous` — check exit code in describe |
| Init:CrashLoopBackOff | Init container crashing | `kubectl logs <pod> -c <init-container>` |
| Init:0/1 | Init container not yet completed | `kubectl logs <pod> -c <init-container>` — may be waiting on dependency |
| Completed | All containers exited with 0 | Normal for Jobs. Unexpected for Deployments — check restart policy |
| Terminating | Pod being deleted | Check for stuck finalizers; may need force delete |
| Unknown | Node unreachable | Check node health — `kubectl get nodes`, `kubectl describe node` |
| ContainerCreating | Image pulling or volume mounting | If stuck: `kubectl describe pod` for mount/pull events |
| PodInitializing | Init containers running | Normal transitional state — check init container logs if stuck |

---

### Common Event Reasons

| Reason | Meaning | Next Step |
|---|---|---|
| Scheduled | Pod assigned to node | Normal |
| Pulled | Image pulled from registry | Normal |
| Created | Container created | Normal |
| Started | Container started | Normal |
| Killing | Container being killed | If unexpected: check liveness probe config |
| BackOff | Backing off restart or pull | Check logs (CrashLoopBackOff) or image (ImagePullBackOff) |
| FailedScheduling | No suitable node found | `kubectl describe pod` — insufficient CPU/memory, taints, node selectors |
| FailedMount | Volume could not be mounted | Check PVC name, StorageClass, volume mount path |
| FailedAttachVolume | PVC exists but can't attach to node | Check PVC bound status, StorageClass provisioner |
| Unhealthy | Readiness or liveness probe failed | `kubectl describe pod` shows which probe and response |
| FailedCreate | ReplicaSet couldn't create pod | `kubectl describe rs` — quota exceeded or invalid spec |
| SuccessfulCreate | Pod created by ReplicaSet | Normal |
| SuccessfulDelete | Pod deleted during scale-down/rollout | Normal |
| RELOAD | nginx Ingress controller reloaded config | Normal — happens when Ingress resources change |
| Sync | Ingress controller synced state | Normal |
| Forbidden | RBAC denied an action | Check ServiceAccount, Role, RoleBinding — `kubectl auth can-i` |
| Evicted | Pod evicted due to resource pressure | Check node resources — `kubectl describe node` |
| NodeNotReady | Pod's node entered NotReady state | `kubectl get nodes`, `kubectl describe node` |
| InsufficientMemory | Node lacks memory to schedule pod | Reduce memory request or add capacity |
| InsufficientCPU | Node lacks CPU to schedule pod | Reduce CPU request or add capacity |
