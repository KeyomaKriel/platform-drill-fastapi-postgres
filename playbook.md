# Kubernetes Troubleshooting Playbook

<a id="rule-0"></a>
## Rule 0

Do not start by guessing the root cause.

Start by answering:

1. What is the visible symptom?
2. Which Kubernetes object type is closest to that symptom?
3. What command will show the truth fastest?

---

<a id="phase-1-universal-triage"></a>
## Phase 1: Universal Triage

Run these first in almost every scenario unless the prompt is extremely explicit.

```bash
kubectl config current-context
kubectl get ns
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
kubectl get ingress -A
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

Say: *"I'm starting with universal triage to identify the failure category. I'm checking context, namespaces, core workloads, services, ingress, resource usage, and recent events. Once I see the strongest signal, I'll stop broad triage and switch to the relevant branch."*

### When to shortcut triage

If the prompt already tells you the exact problem category, skip straight to that bucket. Examples:

- "The deploy-bot service account is getting Forbidden" → skip to [Bucket A](#bucket-a)
- "Pods are stuck in Pending" → skip to [Bucket B](#bucket-b)
- "Users cannot reach the app externally" → skip to [Bucket E](#bucket-e)

If in doubt, run the full triage. It takes under a minute.

### Why these commands

This gives you:

- whether you are on the right cluster/context
- what namespaces exist
- whether anything obvious is broken
- whether a deployment is unavailable
- whether services/ingress exist
- whether nodes or pods are under resource pressure
- whether events already reveal the issue

---

### What to look for in each triage command

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

- if the issue is not context but namespace defaulting, keep the same context and fix the namespace instead:

```bash
kubectl config set-context --current --namespace=<ns>
```

**Verify:**

```bash
kubectl config current-context
kubectl config view --minify
kubectl get ns
```

You are done with this check when the current context matches the scenario and the cluster responds as expected.

---

#### `kubectl get ns`

Look for:

- likely app namespace
- scenario-specific namespace mentioned in prompt

Stop and switch direction if:

- the prompt names a namespace and you were looking elsewhere

**Fix patterns:**

- target the correct namespace explicitly in commands:

```bash
kubectl get pods -n <ns>
```

- set the default namespace for the current context if you want to stop repeating `-n`:

```bash
kubectl config set-context --current --namespace=<ns>
```

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
- ImagePullBackOff / ErrImagePull
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

<a id="quick-signal-table"></a>
## Quick Signal Table

After triage, find the strongest signal and jump to the right bucket.

| What you see | Bucket | Go to |
|---|---|---|
| Forbidden / Unauthorized / cannot create/get/list | **RBAC** | [Bucket A](#bucket-a) |
| Pod status: `ImagePullBackOff` or `ErrImagePull` | **Image / registry** | [Bucket B](#bucket-b) → ImagePull sub-branch |
| Pod status: `Pending` | **Scheduling / resources / storage** | [Bucket B](#bucket-b) → Pending sub-branch |
| Pod status: `CrashLoopBackOff` | **Pod startup / app crash** | [Bucket B](#bucket-b) → CrashLoop sub-branch |
| Pod status: `Running` but READY shows `0/1` | **Readiness probe** | [Bucket B](#bucket-b) → Running-not-Ready sub-branch |
| Pod `Running` + `1/1` but RESTARTS climbing | **Liveness probe** | [Bucket B](#bucket-b) → Liveness sub-branch |
| Pod status: `Init:CrashLoopBackOff` or `Init:0/1` | **Init container** | [Bucket B](#bucket-b) → Init container sub-branch |
| Pod exit code 137 / OOMKilled in describe | **Resource limits** | [Bucket B](#bucket-b) → CrashLoop sub-branch (OOMKilled) |
| Deployment unhealthy but pods not obviously broken | **Deployment / rollout** | [Bucket C](#bucket-c) |
| Pods healthy but app unreachable through Service | **Service routing** | [Bucket D](#bucket-d) |
| Service works (port-forward OK) but external URL fails | **Ingress** | [Bucket E](#bucket-e) |
| Events show missing ConfigMap or Secret | **Configuration injection** | [Bucket F](#bucket-f) |
| Issue is scheduled or batch execution | **Jobs / CronJobs** | [Bucket G](#bucket-g) |
| Pods Running + Ready but app returns 5xx errors | **Application-level** | [Bucket H](#bucket-h) |
| Everything looks healthy but traffic silently times out | **Network policies** | [Bucket I](#bucket-i) |
| PVC stuck in `Pending` | **Storage** | [Bucket J](#bucket-j) |
| Resources appear to be missing entirely | **Namespace confusion** | [Bucket K](#bucket-k) |

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

**In `kubectl auth can-i`:** yes or no. If no, keep going in this bucket. Do not leave this bucket yet.

**In the ServiceAccount YAML:** exact name, namespace.

**In the RoleBinding YAML:**

- `subjects[].kind` should match expectation (often ServiceAccount)
- `subjects[].name` exact match
- `subjects[].namespace` exact match
- `roleRef.name` exact match
- `roleRef.kind` correct (Role vs ClusterRole)

**In the Role YAML:**

- right resources
- right verbs
- right apiGroups

If unsure about API group:

```bash
kubectl api-resources | grep <resource>
kubectl explain <resource>
```

**Common apiGroup reference:**

- `deployments` → apiGroups: `["apps"]`
- `pods`, `services`, `configmaps`, `secrets` → apiGroups: `[""]`
- `ingresses` → apiGroups: `["networking.k8s.io"]`
- `jobs`, `cronjobs` → apiGroups: `["batch"]`

#### Stop condition

Stop this bucket when you can point to the exact broken RBAC link, or `kubectl auth can-i ...` returns yes.

#### Fix patterns

- fix the RoleBinding subject: wrong name, wrong namespace, wrong kind
- fix the roleRef: wrong name, wrong kind
- fix the Role rules: wrong apiGroups, wrong resources, wrong verbs
- if the ServiceAccount itself is wrong or missing: create it or rename references to match
- if the scenario expects namespace-scoped access, use a Role + RoleBinding
- if it expects cluster-wide access, you may need ClusterRole + ClusterRoleBinding

**Important:** You cannot edit the `roleRef` on a RoleBinding. You must delete and recreate it.

```bash
# Fix a Role (wrong verbs, resources, or apiGroups)
kubectl edit role <role> -n <ns>

# Fix a RoleBinding (wrong subject)
kubectl edit rolebinding <binding> -n <ns>

# Delete and recreate RoleBinding (if roleRef is wrong)
kubectl delete rolebinding <binding> -n <ns>
kubectl create rolebinding <n> \
  --role=<role> \
  --serviceaccount=<ns>:<sa> \
  -n <ns>

# Create a missing ClusterRoleBinding
kubectl create clusterrolebinding <n> \
  --clusterrole=<clusterrole> \
  --serviceaccount=<ns>:<sa>

# Or apply from file
kubectl apply -f <file>.yaml
```

#### Verify

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
kubectl get rolebinding <binding> -n <ns> -o yaml
kubectl get role <role> -n <ns> -o yaml
```

You are done when:

- `can-i` returns yes for the required action
- the YAML now reflects the intended RBAC chain
- the original forbidden action succeeds

If `can-i` is now yes but the scenario still fails, only then leave this bucket.

---

<a id="bucket-b"></a>
### Bucket B: Pod / Startup / Scheduling / Workload Health

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** you saw broken pod states, unhealthy restarts, resource pressure, or events pointing at pod-level failure.

Say: *"I see a pod in [status]. Let me describe it and check logs to understand what's happening."*

#### Diagnose

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

**In `describe pod`**, go straight to:

- container state (and init container state)
- restart count
- last termination reason (especially OOMKilled)
- probes (liveness, readiness, startup)
- env/config/secret refs
- Events section at bottom

Signal map:

- FailedScheduling → scheduling/resources/PVC
- FailedMount → volume/config/secret problem
- Unhealthy → probe problem
- image pull errors → image/registry problem
- OOMKilled → resource limits too low or memory leak

**In logs**, look for:

- app startup exceptions
- connection refused to DB / dependency
- missing environment variables
- migration failures
- bind/listen port mismatch
- permission errors (filesystem, network)

Now branch based on the pod status:

---

#### Sub-branch: ImagePullBackOff / ErrImagePull

Say: *"The pod can't pull its container image. I need to check whether it's a wrong image name, a wrong tag, or a registry access issue."*

```bash
kubectl describe pod <pod> -n <ns>
kubectl describe deploy <deploy> -n <ns>
```

Look for: wrong image name, wrong tag, auth issue, image pull secret missing/wrong. The Events section usually says exactly what image it tried to pull and why it failed.

**Stop condition:** Stop when the event clearly shows the pull problem — wrong name, wrong tag, or auth failure.

**Fix patterns:**

- correct the image repository/path
- correct the image tag
- add/fix imagePullSecrets
- fix registry credentials
- if the image does not exist, push/build the correct image or point to a valid tag

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

```bash
kubectl get deploy -n <ns>
kubectl describe deploy <deploy> -n <ns>
kubectl rollout status deploy/<deploy> -n <ns>
kubectl rollout history deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl get pods -n <ns> --show-labels
```

#### What to look for

- desired vs available replicas
- rollout events
- image version/tag
- selector labels vs pod template labels (must match)
- revision history
- old ReplicaSets still running

A stuck rollout typically shows:
- Old RS: desired=1, ready=1
- New RS: desired=1, ready=0

Check the new RS's pods — they usually have a clear error (ImagePullBackOff, CrashLoopBackOff, etc.). If so, go to [**Bucket B**](#bucket-b) to fix the pod issue first.

If the issue is update/rollback behavior, stay here.

#### Stop condition

Stop when you know whether the rollout problem is: bad image, bad labels, bad pod template, or partial rollout needing rollback.

#### Fix patterns

- correct the image/tag in the Deployment
- fix the Deployment selector or pod template labels
- fix the pod template environment/config
- roll back to the previous good revision
- scale appropriately if replica count is wrong for the scenario
- if the Deployment spec is malformed, re-apply the corrected manifest

```bash
# Rollback to previous revision
kubectl rollout undo deploy/<deploy> -n <ns>

# Rollback to a specific revision
kubectl rollout undo deploy/<deploy> -n <ns> --to-revision=<N>

# Fix image
kubectl set image deploy/<deploy> <container>=<correct-image>:<tag> -n <ns>

# Fix label mismatch between selector and pod template
kubectl edit deploy <deploy> -n <ns>
# Ensure spec.selector.matchLabels matches spec.template.metadata.labels

# Scale if needed
kubectl scale deploy/<deploy> --replicas=<N> -n <ns>

# Restart all pods (force new rollout)
kubectl rollout restart deploy/<deploy> -n <ns>
```

#### Verify

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get deploy <deploy> -n <ns>
kubectl get rs -n <ns>
kubectl get pods -n <ns>
```

You are done when the rollout completes successfully and the desired replicas are available.

---

<a id="bucket-d"></a>
### Bucket D: Service / Internal Reachability

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** app seems up but is not reachable through the service.

Say: *"Pods are Running and Ready, but I can't reach the app through the Service. I need to check if the Service is actually routing to the pods — that means checking selectors, endpoints, and ports."*

#### Diagnose

```bash
kubectl get svc -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get endpoints <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl get networkpolicy -n <ns>
```

Then test it:

```bash
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i http://localhost:8080
```

#### What to look for

**In `describe svc`:** selector, service port, targetPort.

**In `get endpoints`:** whether backend pod IPs exist.

**If endpoints are empty:**

- stay in this bucket
- compare service selector to pod labels (exact match required)
- check pod readiness (only Ready pods appear in endpoints)

**If endpoints exist but curl fails:**

- compare targetPort with the port the app is actually listening on
- check for NetworkPolicy blocking traffic → go to [**Bucket I**](#bucket-i)
- maybe shift back to [Bucket B](#bucket-b) if app is unhealthy

**NetworkPolicy check** (often missed):

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy <policy> -n <ns>
```

Look for: ingress/egress rules that block traffic between pods or from the service.

#### Stop condition

Stop when you know whether the problem is: selector mismatch, no ready pods, wrong targetPort, NetworkPolicy blocking traffic, or app behind service still unhealthy.

#### Fix patterns

- fix the Service selector to match the pod labels
- fix the pod labels to match the Service selector
- correct targetPort to match the port the container actually listens on
- correct the service port if the scenario expects a different one
- fix readiness so healthy pods actually become endpoints
- fix or delete a blocking NetworkPolicy
- if the service points to the wrong namespace's assumptions, make sure you are checking the correct namespace rather than patching the wrong object

```bash
# Fix selector mismatch or targetPort
kubectl edit svc <svc> -n <ns>

# Fix pod labels to match service selector
kubectl edit deploy <deploy> -n <ns>

# Fix or delete blocking NetworkPolicy
kubectl edit networkpolicy <policy> -n <ns>
kubectl delete networkpolicy <policy> -n <ns>

# Create a missing service
kubectl expose deploy <deploy> --port=<svc-port> --target-port=<container-port> -n <ns>

# Or apply from file
kubectl apply -f <service-file>.yaml
```

#### Verify

```bash
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i http://localhost:8080
```

You are done when:

- endpoints are populated with the correct backends
- curl through the service works
- the service now routes to the intended pods

---

<a id="bucket-e"></a>
### Bucket E: Ingress / External Routing

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the problem is external URL / host / path routing.

Say: *"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer — something between the external URL and the Service."*

**Important rule:** if service/endpoints are broken, go back to [**Bucket D**](#bucket-d) first. Do not waste time blaming ingress when the service chain underneath is broken.

#### Diagnose

```bash
kubectl get ingress -n <ns>
kubectl describe ingress <ing> -n <ns>
kubectl get svc -n <ns>
kubectl get endpoints <svc> -n <ns>
```

Then test:

```bash
curl -H "Host: <host>" -i http://<ingress-ip>
curl -H "Host: <host>" -i http://<ingress-ip>/<path>
```

#### What to look for

- correct host
- correct path and pathType
- correct backend service name
- correct backend port (number or name)
- ingress class annotation or `spec.ingressClassName`
- address assigned (if blank, ingress controller may not be running)

#### Stop condition

Stop when you can say: host/path mismatch, wrong backend service, wrong backend port, or ingress class/address issue.

#### Fix patterns

- correct the host rule
- correct the path rule
- correct the backend service name
- correct the backend service port
- fix or add the correct ingress class annotation/spec field
- if ingress has no address because the controller is not functioning, confirm controller health before editing the Ingress blindly
- if external routing is fine but the service is broken, stop here and go back to [Bucket D](#bucket-d)

```bash
# Fix host, path, backend service, or backend port
kubectl edit ingress <ing> -n <ns>

# Or apply from file
kubectl apply -f <ingress-file>.yaml

# If ingress controller is not running
kubectl get pods -n ingress-nginx   # or the relevant namespace
kubectl describe deploy -n ingress-nginx
```

#### Verify

```bash
kubectl describe ingress <ing> -n <ns>
curl -H "Host: <host>" -i http://<ingress-ip>
kubectl get svc -n <ns>
kubectl get endpoints <svc> -n <ns>
```

You are done when the host/path rule matches the intended backend and the external request behaves correctly.

---

<a id="bucket-f"></a>
### Bucket F: Config / Secret / Volume / Dependency Setup

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the app is failing due to setup/configuration rather than routing.

Say: *"I see events or pod errors about a missing ConfigMap or Secret. The pod can't start because it's trying to reference configuration that doesn't exist or is named wrong."*

#### Diagnose

```bash
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o yaml
```

Check what the Deployment references:

```bash
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 3 "configMapRef\|secretRef\|configMapKeyRef\|secretKeyRef\|volumes"
```

Check what actually exists:

```bash
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
```

#### What to look for

- missing secret/configmap refs (events will say "not found")
- env vars referencing wrong configmap/secret names
- mounted files missing or at wrong paths
- volume mount paths wrong
- app logs complaining about credentials, connection strings, or missing settings

If it is a mount issue, inspect `volumes` and `volumeMounts` in the pod YAML carefully.

If it is a secret/config ref issue, inspect names character by character.

#### Stop condition

Stop when you identify: missing object, wrong reference name, wrong mount path, or wrong env source.

#### Fix patterns

- create the missing ConfigMap or Secret
- correct the referenced object name in the pod/deployment spec
- fix the key name used by env or envFrom
- correct the mount path
- correct the volume name / volumeMount linkage
- restart/roll out the workload if the config change requires a new pod
- if the config object exists in a different namespace, stop and correct namespace assumptions rather than duplicating blindly unless the scenario requires duplication

```bash
# Create a missing ConfigMap
kubectl create configmap <n> --from-literal=<key>=<value> -n <ns>
kubectl create configmap <n> --from-file=<path> -n <ns>

# Create a missing Secret
kubectl create secret generic <n> --from-literal=<key>=<value> -n <ns>

# Fix a wrong env var reference or mount path
kubectl edit deploy <deploy> -n <ns>
# Correct env[].valueFrom.configMapKeyRef.name/.key or volumeMounts[].mountPath

# Fix a ConfigMap or Secret value
kubectl edit configmap <cm> -n <ns>
kubectl edit secret <secret> -n <ns>

# Decode a secret value to check it
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# After editing a ConfigMap or Secret, restart to pick up changes
kubectl rollout restart deploy/<deploy> -n <ns>
```

#### Verify

```bash
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl exec <pod> -n <ns> -- env | grep <expected-var>
```

You are done when the references are correct, mounts/env are present, and the app stops failing for that missing-config reason.

---

<a id="bucket-g"></a>
### Bucket G: Jobs / CronJobs

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** the scenario is batch/scheduled work.

Say: *"This is a Job or CronJob issue. I need to check whether the job itself is misconfigured, or if the pods it creates are failing."*

#### Diagnose

```bash
kubectl get jobs -A
kubectl get cronjobs -A
kubectl describe job <job> -n <ns>
kubectl describe cronjob <cj> -n <ns>
kubectl get pods -n <ns>
kubectl logs <job-pod> -n <ns>
```

#### What to look for

- job completions vs desired
- backoffLimit reached
- failed pods
- schedule syntax (cron format)
- suspend field (is the CronJob paused?)
- concurrencyPolicy
- pod logs for runtime errors

#### Stop condition

Stop when you know whether it is: job pod failing, schedule misconfigured, concurrency issue, or image/config/runtime issue inside the job.

#### Fix patterns

- correct the Job image/command/args
- fix environment/config/secrets used by the Job
- correct the CronJob schedule
- fix restart/backoff behavior if the task should retry differently
- remove/recreate or re-run the Job if the scenario requires a fresh execution after fixing the spec
- if the Job pods are failing for the same reasons as normal app pods, reuse [Bucket B](#bucket-b) or [Bucket F](#bucket-f) fix patterns

```bash
# Fix schedule syntax or unsuspend
kubectl edit cronjob <cj> -n <ns>
# Correct spec.schedule (standard cron: "*/5 * * * *")

# Unsuspend a CronJob
kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"suspend":false}}'

# Manually trigger a CronJob to test
kubectl create job --from=cronjob/<cj> <manual-job-name> -n <ns>

# Delete a stuck/failed job to re-run
kubectl delete job <job> -n <ns>

# Fix image or command
kubectl edit job <job> -n <ns>
```

#### Verify

```bash
kubectl get jobs -n <ns>
kubectl describe job <job> -n <ns>
kubectl get pods -n <ns>
kubectl logs <job-pod> -n <ns>
```

You are done when the Job completes successfully or the CronJob produces successful runs on the corrected schedule.

---

<a id="bucket-h"></a>
### Bucket H: Application-Level Failures

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** pods are Running and Ready, endpoints are populated, but the app returns 5xx errors or wrong responses. Kubernetes thinks everything is fine.

Say: *"Everything looks healthy from a Kubernetes perspective — pods are Running, Ready, endpoints are populated. So this is an application-level issue. Logs should tell me what's going on."*

#### Diagnose

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --tail=50
```

Check what environment the app is actually seeing:

```bash
kubectl exec <pod> -n <ns> -- env | sort
```

Cross-reference with what the ConfigMap and Secret contain:

```bash
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data}' | jq 'to_entries[] | {key: .key, value: (.value | @base64d)}'
```

If `jq` isn't available:

```bash
kubectl get secret <secret> -n <ns> -o yaml
# Decode values manually:
echo "<base64-value>" | base64 -d
```

#### What to look for

| Log message | Cause | Fix |
|---|---|---|
| `connection refused` to DB host | Wrong hostname or DB not running | Check the hostname in ConfigMap, check DB pod status |
| `password authentication failed` | Wrong credentials | Fix the Secret |
| `database "X" does not exist` | Wrong database name in config | Fix the ConfigMap |
| `relation "X" does not exist` | DB schema not initialized | Check if init ran, check DB connectivity during startup |
| `Name or service not known` | DNS can't resolve the hostname | Check the service name, check if DB service exists |
| `connect ECONNREFUSED` | App can reach host but port is wrong or service is down | Check port in config, check target pod |

#### Stop condition

Stop when you can identify the exact config value or dependency that's causing the application error from the logs.

#### Fix patterns

```bash
# Fix ConfigMap values
kubectl edit configmap <cm> -n <ns>

# Fix Secret values
kubectl edit secret <secret> -n <ns>

# After editing config, restart the pods to pick up the change
kubectl rollout restart deployment/<deploy> -n <ns>
```

#### Verify

```bash
kubectl get pods -n <ns> -w
kubectl logs <pod> -n <ns>
curl http://localhost/health
curl http://localhost/items
```

You are done when the app responds correctly and logs show no errors.

---

<a id="bucket-i"></a>
### Bucket I: Network Policies

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** everything looks correct — pods Running, Ready, endpoints populated, services exist — but traffic silently fails or times out. No error messages, just no response.

Say: *"Everything looks healthy but traffic is failing silently. When all the obvious things check out, it's often a NetworkPolicy blocking traffic. Let me check."*

#### Diagnose

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
```

Read each policy carefully. Check:

- `podSelector`: which pods does this policy apply to?
- `policyTypes`: is it Ingress, Egress, or both?
- `ingress` rules: who is allowed to send traffic TO the selected pods?
- `egress` rules: where are the selected pods allowed to send traffic?

#### What to look for

A NetworkPolicy with an empty `podSelector` (`{}`) applies to ALL pods in the namespace.

If `policyTypes` includes `Ingress` or `Egress`, then any traffic not explicitly allowed by a rule is **denied**.

Common problems:
- Default deny policy exists but no matching allow rule for the traffic flow you need
- Allow rule has wrong `podSelector` or `namespaceSelector`
- Allow rule is missing the port specification
- Egress policy blocks DNS (must allow egress to kube-system on port 53 TCP and UDP)

#### Stop condition

Stop when you identify which NetworkPolicy is blocking which traffic flow, or confirm that NetworkPolicies are not the issue.

#### Quick test — temporarily remove policies

If you suspect a NetworkPolicy but can't tell which one, delete one at a time and test after each:

```bash
kubectl get networkpolicy -n <ns> -o name
kubectl delete networkpolicy <policy-name> -n <ns>
curl http://localhost/
```

If traffic works after deleting a specific policy, that was the blocker. Now you know what to fix.

#### Fix patterns

**Add a missing allow rule:**

Example — allow app to reach postgres:

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

Example — allow DNS:

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

**Delete a blocking policy:**

```bash
kubectl delete networkpolicy <policy-name> -n <ns>
```

#### Verify

```bash
kubectl get networkpolicy -n <ns>
curl http://localhost/
kubectl exec <app-pod> -n <ns> -- curl -s http://<svc>:<port>
```

You are done when traffic flows correctly between the expected services.

---

<a id="bucket-j"></a>
### Bucket J: Storage

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** a PVC is stuck in Pending, or a pod can't start because of a volume issue.

Say: *"I see a PVC stuck in Pending. That means it can't bind to a PersistentVolume. I need to check if there's a matching StorageClass and if the request is valid."*

#### Diagnose

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv
kubectl get storageclass
```

#### What to look for

Check the Events on the PVC for the reason.

| Event message | Cause | Fix |
|---|---|---|
| `no persistent volumes available` and no StorageClass | No default StorageClass, no matching PV | Create a StorageClass or PV |
| `storageclass "X" not found` | PVC requests a StorageClass that doesn't exist | Fix the StorageClass name in the PVC or create it |
| Capacity mismatch | PV exists but is too small | Create a larger PV or reduce the PVC request |
| Access mode mismatch | PVC asks for ReadWriteMany but PV only supports ReadWriteOnce | Fix the access mode |
| PV already bound | PV is bound to a different PVC | Create a new PV |
| Wrong mount path in pod | PVC is bound but app can't find data | Check volumeMounts in pod spec |

#### Stop condition

Stop when you know why the PVC can't bind or why the volume isn't working correctly.

#### Fix patterns

You usually need to recreate the PVC (you can't edit most PVC fields):

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

Fix a wrong volume mount path:

```bash
kubectl edit deployment <deploy> -n <ns>
# Correct spec.template.spec.containers[].volumeMounts[].mountPath
```

You may also need to restart the pod that uses this PVC:

```bash
kubectl rollout restart deployment/<deploy> -n <ns>
```

#### Verify

```bash
kubectl get pvc -n <ns>
kubectl get pods -n <ns> -w
```

You are done when the PVC shows `Bound` and the pod using it starts successfully.

---

<a id="bucket-k"></a>
### Bucket K: Namespace Confusion

[Back to Quick Signal Table](#quick-signal-table)

**Start here if** resources appear to be missing entirely — you expect pods, services, or other objects but they don't show up.

Say: *"I'm not seeing the resources I expect. Let me check if they're deployed to a different namespace."*

#### Diagnose

```bash
kubectl get all -A
kubectl get ns
```

Look for resources in an unexpected namespace. Common variant: there are two similarly named namespaces and resources are split between them.

Also check if you've been defaulted to the wrong namespace:

```bash
kubectl config view --minify | grep namespace
```

#### Stop condition

Stop when you find where the resources actually are, or confirm they genuinely don't exist.

#### Fix patterns

Either move the resources (delete and recreate in the correct namespace) or update references to point to the right namespace.

To reference a service in a different namespace from within the cluster:

```
<service-name>.<namespace>.svc.cluster.local
```

Set the correct default namespace:

```bash
kubectl config set-context --current --namespace=<ns>
```

If resources were applied to the wrong namespace:

```bash
# Export, fix namespace, re-apply
kubectl get <resource> <n> -n <wrong-ns> -o yaml > fix.yaml
# Edit fix.yaml to change namespace
kubectl apply -f fix.yaml
kubectl delete <resource> <n> -n <wrong-ns>
```

#### Verify

```bash
kubectl get all -n <correct-ns>
```

You are done when all expected resources exist in the correct namespace.

---

<a id="when-to-stop-triaging"></a>
## When to Stop Triaging and Commit

You stop generic triage as soon as you get a clear strongest signal.

Examples:

- `kubectl auth can-i ...` = no → stop and commit to RBAC
- pod shows CrashLoopBackOff with restart events → stop and commit to pod/startup
- service has empty endpoints while pods are healthy → stop and commit to service
- ingress returns 404 with wrong host/path rules → stop and commit to ingress
- logs say secret missing / config invalid → stop and commit to config
- everything healthy but traffic times out → stop and commit to network policies
- resources missing in expected namespace → stop and commit to namespace confusion

Do not keep doing all buckets "just in case." That wastes time.

---

<a id="fix-discipline"></a>
## Fix Discipline

- Once the strongest signal is clear, stop broad scanning.
- Make the **smallest fix** that matches the strongest confirmed signal.
- Do **not** patch multiple unrelated objects at once unless the scenario clearly requires it.
- After verifying the fix, only then go back up a level if another symptom remains.

**Post-fix verify pattern:**

After any fix, re-run the smallest set of commands that proves the specific issue is resolved before returning to broad triage:

- RBAC fix → re-run `kubectl auth can-i`
- Pod/startup fix → re-run `kubectl get pods`, `describe`, `logs`
- Service fix → re-run `get endpoints`, `port-forward`, `curl`
- Ingress fix → re-run `describe ingress`, `curl -H "Host: ..."`
- Config fix → re-run pod logs and inspect references
- Namespace/context fix → re-run `kubectl config current-context`, `kubectl get ns`, then target the correct namespace
- Network policy fix → re-run `curl` or `kubectl exec` to test traffic
- Storage fix → re-run `kubectl get pvc`, `kubectl get pods`
- Application fix → re-run `curl` against the app endpoints, check logs

Then always do end-to-end verification:

Say: *"I've applied the fix. Now I'm verifying end-to-end to make sure the issue is fully resolved."*

```bash
kubectl get pods -n <ns>
kubectl get endpoints -n <ns>
curl http://localhost/
curl http://localhost/health
curl http://localhost/items
```

---

<a id="what-to-say-out-loud"></a>
## What to Say Out Loud (Interview)

Opening:

> "I'm starting with universal triage to identify the failure category. I'm checking context, namespaces, core workloads, services, ingress, resource usage, and recent events. Once I see the strongest signal, I'll stop broad triage and switch to the relevant branch."

After identifying the signal:

> "The strongest signal here is [signal], so I'm treating this as a [bucket] problem."

During diagnosis:

> "I see the pod is in CrashLoopBackOff — let me check logs to understand why it's crashing."
>
> "Endpoints are empty, which tells me the service selector doesn't match any pod labels. Let me compare them."
>
> "Everything looks healthy from a Kubernetes perspective — pods are Running, endpoints are populated. So this is probably an application-level issue. Let me check the logs."
>
> "The pod is Pending. I want to check if it's a resource issue or a storage issue — `describe pod` should tell me."
>
> "I see `Init:0/1` — this pod has an init container that hasn't completed. Let me get the init container logs specifically."
>
> "All the obvious things look correct but traffic is timing out. That makes me think there might be a NetworkPolicy blocking traffic. Let me check."
>
> "My theory is [X]. Let me test that by running [Y]. If I'm wrong, I'll reconsider."

After fixing:

> "I've applied the fix. Now I'm verifying by re-running the relevant checks to confirm the issue is resolved."

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
2. Run [universal triage](#phase-1-universal-triage)
3. Identify strongest signal using the [Quick Signal Table](#quick-signal-table)
4. Commit to one bucket
5. Run that bucket's diagnostic commands
6. Stop when root cause category is clear ([when to stop](#when-to-stop-triaging))
7. Apply the smallest fix that resolves the confirmed issue ([fix discipline](#fix-discipline))
8. Verify the fix worked (bucket-specific, then end-to-end)
