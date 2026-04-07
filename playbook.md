# Kubernetes Troubleshooting Playbook

## Table of Contents

- [Rule 0](#rule-0)
- [Entry Modes](#entry-modes)
- [Interview Runtime Flow](#interview-runtime-flow)
- [Symptom-to-Domain Table](#symptom-table)
- Failure Domains
  - [RBAC / Service Account / Permissions](#rbac)
  - [Image Pull / Container Creation](#image-pull)
  - [Startup / Crash](#startup-crash)
  - [Probe Failure](#probe-failure)
  - [Config / Secret / Env / Volume Injection](#config-injection)
  - [Resource / Scheduling / Storage](#resource-scheduling)
  - [Service Routing / Ports / Endpoints](#service-routing)
  - [DNS / Namespace / Service Discovery](#dns-namespace)
  - [Ingress / External Routing](#ingress)
  - [NetworkPolicy / Traffic Restriction](#networkpolicy)
  - [Deployment / Rollout](#deployment-rollout)
  - [Application-Level Failure](#app-failure)
  - [Jobs / CronJobs](#jobs-cronjobs)
- [Quick Reference](#quick-reference)
- [Appendix A: Exit Codes and Pod Statuses](#appendix-exit-codes)
- [Appendix B: HTTP Status Codes](#appendix-http)

---

<a id="rule-0"></a>
## Rule 0

Do not start by guessing the root cause.

Start by answering:

1. What is the visible symptom?
2. Which Kubernetes object type is closest to that symptom?
3. What command will show the truth fastest?

---

<a id="entry-modes"></a>
## Entry Modes

There are two ways to start. Pick one based on what you know.

### Full Triage

**Use when:** scope is ambiguous, multiple things may be broken, or the scenario is "investigate this cluster."

Say: *"The scope is unclear, so I'm going to orient broadly before I commit to a direction."*

```bash
kubectl config current-context
kubectl get ns
kubectl get all -n <ns>
kubectl get ingress -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

Work through these in order. At each step, read the output for signals. As soon as you see a clear signal, stop broad triage and commit to a failure domain using the [Symptom-to-Domain Table](#symptom-table).

If no signal is obvious after these five commands, also check:

```bash
kubectl top nodes
kubectl top pods -n <ns>
kubectl get networkpolicy -n <ns>
```

Full triage takes under a minute. Do not skip it when scope is unclear.

**Setting default namespace** — once you identify the target namespace, set it to avoid repeating `-n`:

```bash
kubectl config set-context --current --namespace=<ns>
```

### Fast Path

**Use when:** you know the app, you know the symptom, you just don't know the cause. Examples: *"The app is down"*, *"The pod keeps restarting"*, *"Users can't reach the service."*

The rule: **known app + known symptom + unknown cause = Fast Path.**

Say: *"This looks like a single workload problem, so I'm going straight to pods, then logs, then testing reachability layer by layer."*

1. `kubectl get pods -n <ns>` — check pod status
2. `kubectl describe pod <pod> -n <ns>` + `kubectl logs <pod> -n <ns>` — identify the failure
3. If pods are healthy, test pod directly: `kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>` then `curl localhost:8080/`
4. If pod responds, test service: `kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>` then `curl localhost:8080/`
5. If service works, test ingress: `curl localhost/` or `curl -H "Host: <host>" localhost/`

You can start with full triage and switch to Fast Path mid-flow once you have a signal. That is usually the safest pattern: 20-40 seconds of orientation, then commit.

---

<a id="interview-runtime-flow"></a>
## Interview Runtime Flow

This is the practical loop for live use. It is distinct from the failure domain sections below — those are reference material. This is what you actually do, step by step.

**1. Orient** — avoid wrong context/namespace.

```bash
kubectl config current-context
kubectl get ns
```

If the context or namespace is wrong, fix it before touching anything else.

**2. Identify the workload** — if not already known.

```bash
kubectl get all -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

Say: *"I'm looking at the full picture — what's running, what's failing, and any recent events."*

**3. Check pod state.**

```bash
kubectl get pods -n <ns>
```

Read STATUS, READY, and RESTARTS. If something is obviously wrong, say what you see and commit to a domain.

**4. Describe the relevant pod.**

```bash
kubectl describe pod <pod> -n <ns>
```

Read: State, Last State (exit codes), Conditions, Events (bottom). This single command often names the root cause directly.

**5. Check logs.**

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
```

Use `--previous` when the container has already crashed. Use `-c <container>` for init containers or sidecars.

**6. If the pod is healthy, test pod reachability.**

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i localhost:8080/
curl -i localhost:8080/health
```

If this fails, the app itself is broken — check logs and env vars. Go to [Application-Level Failure](#app-failure) or [Config Injection](#config-injection).

**7. Test Service and Endpoints.**

```bash
kubectl get endpoints <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

Empty endpoints = selector mismatch. Go to [Service Routing](#service-routing).

**8. Test Ingress / external path.**

```bash
curl -i localhost/
curl -i localhost/health
```

If service works but external URL fails, go to [Ingress](#ingress). If traffic times out silently, consider [NetworkPolicy](#networkpolicy).

**9. If it's not a reachability path problem**, branch into the relevant failure domain using the [Symptom-to-Domain Table](#symptom-table).

**10. Apply the smallest fix and verify.**

Change one thing. Verify it worked. Then verify end-to-end — not just that pods are Running, but that you can reach the app and get a valid response.

Say: *"I've applied the fix. Now I'm verifying end-to-end — pods, endpoints, and an actual request through the full path."*

---

<a id="symptom-table"></a>
## Symptom-to-Domain Table

Use this to jump from what you see (or hear) to the right failure domain.

| What you see or hear | Domain | Go to |
|---|---|---|
| Forbidden / Unauthorized / "service account can't do X" | RBAC | [RBAC](#rbac) |
| `ImagePullBackOff` / `ErrImagePull` / `ErrImageNeverPull` | Image pull | [Image Pull](#image-pull) |
| `CrashLoopBackOff` / "app keeps restarting" | Startup / crash | [Startup / Crash](#startup-crash) |
| Pod exit code 137 / OOMKilled in describe | Resource limits | [Resource / Scheduling](#resource-scheduling) |
| `Pending` / "pods won't schedule" | Scheduling / resources | [Resource / Scheduling](#resource-scheduling) |
| `Init:CrashLoopBackOff` or `Init:0/1` | Init container | [Startup / Crash](#startup-crash) (init container section) |
| Pod `Running` but READY shows `0/1` | Readiness probe | [Probe Failure](#probe-failure) |
| Pod `Running` + `1/1` but RESTARTS climbing | Liveness probe | [Probe Failure](#probe-failure) |
| Events show missing ConfigMap or Secret | Config injection | [Config Injection](#config-injection) |
| Pods healthy but app unreachable through Service | Service routing | [Service Routing](#service-routing) |
| Service works (port-forward OK) but external URL fails | Ingress | [Ingress](#ingress) |
| Everything looks healthy but traffic silently times out | Network policies | [NetworkPolicy](#networkpolicy) |
| PVC stuck in `Pending` / volume mount errors | Storage | [Resource / Scheduling](#resource-scheduling) |
| Deployment unhealthy but pods not obviously broken | Rollout | [Deployment / Rollout](#deployment-rollout) |
| Pods Running + Ready but app returns 5xx | Application-level | [Application-Level](#app-failure) |
| Resources appear missing entirely | Namespace confusion | [DNS / Namespace](#dns-namespace) |
| "Cronjob not running" / batch issue | Jobs | [Jobs / CronJobs](#jobs-cronjobs) |
| `Name or service not known` / DNS failure | DNS | [DNS / Namespace](#dns-namespace) |

If multiple signals compete, pick the one closest to the root. Pod issues before Service issues. Config issues before app crash issues.

Say: *"The strongest signal I'm seeing is [X], so I'm treating this as a [domain] problem. Let me dig into that specifically."*

---

## Failure Domains

---

<a id="rbac"></a>
### RBAC / Service Account / Permissions

**Start here if** you saw Forbidden, Unauthorized, or a service account cannot perform an action.

Say: *"I see a Forbidden error, so this is an RBAC problem. I need to check the ServiceAccount, the Role, and the RoleBinding to find the broken link in the chain."*

#### Commands

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
kubectl get sa,role,rolebinding -n <ns>
kubectl get rolebinding <binding> -n <ns> -o yaml
kubectl get role <role> -n <ns> -o yaml
```

If you don't know the SA name: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.serviceAccountName}'`

#### What the output usually implies

**`auth can-i` returns `no`** — the permission chain is broken. Walk the chain:

**RoleBinding `subjects` field:**
- `name` must exactly match the SA name (check for typos, e.g., `app` vs `app-sa`)
- `namespace` must match where the SA lives (omitted = silent mismatch)
- `kind` must be `ServiceAccount`

**RoleBinding `roleRef` field:**
- `name` must match an existing Role (`kubectl get role -n <ns>` to verify)
- `roleRef` is immutable — if wrong, delete and recreate the binding

**Role `rules` field — all three must be correct:**

| Field | Common mistake |
|---|---|
| `apiGroups` | `["v1"]` instead of `[""]` for core resources |
| `resources` | `["pod"]` singular instead of `["pods"]` plural |
| `verbs` | `["read"]` is not valid; use `["get","list","watch"]` |

**Common apiGroup reference:** `pods`, `services`, `configmaps`, `secrets` → `[""]}`. `deployments`, `replicasets` → `["apps"]`. `ingresses`, `networkpolicies` → `["networking.k8s.io"]`. `jobs`, `cronjobs` → `["batch"]`.

If unsure: `kubectl api-resources | grep <resource>`

#### Likely fixes

**Subject name or namespace wrong in RoleBinding:** `kubectl edit rolebinding <binding> -n <ns>` — correct `subjects[].name` and `subjects[].namespace`.

**RoleRef points to wrong Role:** Must delete and recreate (immutable):

```bash
kubectl delete rolebinding <binding> -n <ns>
kubectl create rolebinding <binding> \
  --role=<correct-role> \
  --serviceaccount=<ns>:<sa> \
  -n <ns>
```

**Role missing required permissions:** `kubectl edit role <role> -n <ns>` — add missing verb/resource/apiGroup to `rules[]`.

**ServiceAccount doesn't exist:** `kubectl create serviceaccount <sa> -n <ns>`

#### Verify

```bash
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>
# Expected: yes
```

Say: *"Permission check returns yes, the RBAC chain is consistent. RBAC is healthy."*

---

<a id="image-pull"></a>
### Image Pull / Container Creation

**Start here if** pod shows `ImagePullBackOff`, `ErrImagePull`, or `ErrImageNeverPull`.

Say: *"The pod can't pull its container image. I need to check whether it's a wrong image name, a wrong tag, or a registry access issue."*

Note: `ErrImageNeverPull` means `imagePullPolicy: Never` but the image doesn't exist locally on the node. Common in kind/minikube where images are loaded directly.

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].image}'
```

**To find the correct (previously working) image:**

```bash
kubectl get pod <old-pod> -n <ns> -o jsonpath='{.spec.containers[0].image}'
kubectl rollout history deploy/<deploy> -n <ns>
kubectl rollout history deploy/<deploy> -n <ns> --revision=<N>
```

#### What the output usually implies

- **Events section** shows `Failed to pull image "myapp:badtag"` — the exact image string is in this message. Compare against the known-good image.
- **`unauthorized: authentication required`** — image exists but credentials are missing. Check `imagePullSecrets`: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.imagePullSecrets}'`
- Typo in registry/repo name (e.g., `ngixn` instead of `nginx`), nonexistent tag, or missing registry prefix.

#### Likely fixes

```bash
# Fix image name or tag
kubectl set image deployment/<deploy> <container>=<correct-image>:<tag> -n <ns>

# If you don't know the container name
kubectl get deployment <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[*].name}'

# Or rollback entirely
kubectl rollout undo deploy/<deploy> -n <ns>

# Create image pull secret if auth is the issue
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass> \
  -n <ns>
```

`kubectl rollout undo` reverts the entire pod template — use when you want a full rollback. `kubectl set image` changes only the image — use when other spec changes are intentional.

#### Verify

```bash
kubectl get pods -n <ns> -w
# Pod pulls successfully and moves past image pull error
```

---

<a id="startup-crash"></a>
### Startup / Crash

**Start here if** pod shows `CrashLoopBackOff`, `Error`, `Init:0/1`, `Init:CrashLoopBackOff`, or has a suspiciously high restart count.

Say: *"The container is crashing repeatedly. I need to check the logs and exit code to understand why."*

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -c <container> -n <ns>   # for init containers or sidecars
```

#### What the output usually implies

**Exit codes** (from `describe pod` → Last State):

| Code | Meaning | Next step |
|---|---|---|
| `0` | Clean exit (unexpected for long-running app) | Check `restartPolicy`, command/args |
| `1` | Application error | Read the logs |
| `137` | OOMKilled (128 + 9) | Check memory limits → [Resource / Scheduling](#resource-scheduling) |
| `139` | Segfault | Image/binary issue |
| `143` | SIGTERM | Usually liveness kill → [Probe Failure](#probe-failure) |

**Log patterns:**

| Log message | Likely cause | Go to |
|---|---|---|
| `connection refused` / `ECONNREFUSED` | Wrong hostname or dependency down | [Application-Level](#app-failure) or [Config Injection](#config-injection) |
| `password authentication failed` | Wrong credentials | [Config Injection](#config-injection) |
| `database "X" does not exist` | Wrong DB name | [Config Injection](#config-injection) |
| Stack trace / panic on startup | App bug or bad image | Rollback image |
| No log output at all | Bad `command` or `args` override | Check pod spec command/args |

**For dependency errors**, cross-reference what the pod actually uses:

```bash
kubectl exec <pod> -n <ns> -- env | sort
kubectl get svc -n <ns>
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
```

#### Init container failures

If the pod shows `Init:0/1` or `Init:CrashLoopBackOff`:

Say: *"I see Init:0/1 — the init container hasn't completed. The main container won't start until it succeeds. Let me check the init container logs specifically."*

**Important:** `kubectl logs <pod>` without `-c` shows the main container. Init container logs require `-c <init-container-name>`.

```bash
kubectl describe pod <pod> -n <ns>         # find init container name under Init Containers:
kubectl logs <pod> -c <init-container> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.initContainers[0].command}'
```

Compare the hostname/port the init container is waiting on against actual services:

```bash
kubectl get svc -n <ns>
kubectl get endpoints <svc> -n <ns>
```

| Init container symptom | Cause | Fix |
|---|---|---|
| Loops waiting for a service | Target service missing or misnamed | Create the service or fix the hostname |
| Can't connect to a port | NetworkPolicy blocking, or target pod not ready | Check [NetworkPolicy](#networkpolicy) or target pod |
| Exits with error | Bad command, wrong image, missing config | Read logs, fix command/image/config |

Usually you fix what the init container is waiting on, not the init container itself.

#### Likely fixes

**Container exits with no logs (bad command/args):** `kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 5 "command\|args"` — correct or remove the override with `kubectl edit deployment <deploy> -n <ns>`.

**OOMKilled (exit 137):** `kubectl edit deploy <deploy> -n <ns>` — increase `resources.limits.memory`. Confirm usage first if metrics are available: `kubectl top pod <pod> -n <ns>`.

**App crash from bad config:** Fix the ConfigMap/Secret (see [Config Injection](#config-injection)), then `kubectl rollout restart deploy/<deploy> -n <ns>`.

**App crash from bad image:** `kubectl rollout undo deploy/<deploy> -n <ns>`.

**Probe killing healthy container:** Fix the probe — see [Probe Failure](#probe-failure).

#### Verify

```bash
kubectl get pods -n <ns>
kubectl logs <pod> -n <ns>
# Restarts stop climbing, pod stays Running, logs are clean
```

---

<a id="probe-failure"></a>
### Probe Failure

**Start here if** pod is `Running` but not Ready (`0/1`), or Running with RESTARTS climbing.

#### Readiness probe

Say: *"The pod is Running but not Ready — the readiness probe is failing. It won't receive traffic until it passes. Let me check what the probe is targeting and whether the app actually responds there."*

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].readinessProbe}'
```

Look for `Readiness probe failed` in Events. Note the path, port, and timing.

**Test what the app actually responds to:**

```bash
kubectl port-forward pod/<pod> 8080:<container-port> -n <ns>
curl -i localhost:8080/
curl -i localhost:8080/health
curl -i localhost:8080/healthz
curl -i localhost:8080/ready
```

Also check startup logs for registered routes: `kubectl logs <pod> -n <ns> | head -30`

**Compare** the configured `readinessProbe.httpGet.path` and `port` against what actually returns 200. If the configured path returns 404 but another path returns 200, the probe path is wrong. If nothing responds, the port is wrong or the app is genuinely unhealthy.

If a stuck rollout has an old working pod, compare its probe as source of truth: `kubectl get pod <old-pod> -n <ns> -o jsonpath='{.spec.containers[0].readinessProbe}'`

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path | Path returns 404, different path returns 200 | Edit deploy, fix path |
| Wrong probe port | `connection refused` on probe | Edit deploy, fix port |
| initialDelaySeconds too short | Fails briefly then passes | Increase initialDelaySeconds |
| App genuinely unhealthy | Probe correct, app has a real problem | Check logs → [Application-Level](#app-failure) |

#### Liveness probe

Say: *"The pod is Running and Ready but restarts keep climbing. The liveness probe is periodically killing the container. I need to check if the probe is misconfigured or the app is genuinely becoming unhealthy."*

```bash
kubectl describe pod <pod> -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].livenessProbe}'
```

Look for `Liveness probe failed` in Events.

Same diagnostic approach as readiness: port-forward and curl the probe path manually. If the path/port is correct but the app is slow, compare `timeoutSeconds` against actual response time.

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path or port | Same as readiness | Edit deploy, fix path/port |
| Timing too aggressive | App responds correctly but slowly | Increase `timeoutSeconds`, `periodSeconds`, or `failureThreshold` |
| App genuinely unhealthy | Probe is correct, app crashes under load | Fix the app, not the probe |

#### Likely fixes

```bash
kubectl edit deploy <deploy> -n <ns>
# Fix readinessProbe.httpGet.path, .port, .initialDelaySeconds
# Fix livenessProbe.httpGet.path, .port, .timeoutSeconds, .failureThreshold
```

#### Verify

```bash
kubectl get pods -n <ns>
# Pod becomes 1/1 Ready (readiness) or restarts stop climbing (liveness)
kubectl get endpoints <svc> -n <ns>
# Endpoints populate once readiness passes
```

---

<a id="config-injection"></a>
### Config / Secret / Env / Volume Injection

**Start here if** events show missing ConfigMap or Secret, or the pod references a config object that doesn't exist or has the wrong name.

This section covers **Kubernetes-side** injection problems: missing objects, wrong references, wrong keys, mount issues. If the objects exist and are correctly injected but the *values* inside them are wrong for the application, go to [Application-Level Failure](#app-failure).

Say: *"I see the pod is failing because of configuration. This could be a missing ConfigMap or Secret, a wrong reference name, or a mount issue. I need to check what the pod is referencing versus what actually exists."*

#### Commands

```bash
kubectl describe pod <pod> -n <ns>
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].envFrom}'
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A2 -E 'configMapRef|secretRef'
```

#### What the output usually implies

**Events section:** `Warning  Failed  ... Error: configmap "<cm>" not found` or `secret "<secret>" not found` — names the exact missing resource.

**Environment block in describe:** Each env var sourced from a ConfigMap/Secret shows the source name. Compare character-for-character against `kubectl get configmap -n <ns>` / `kubectl get secret -n <ns>`.

**`envFrom` references:** `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].envFrom}'` shows what the pod references. Compare against what actually exists. Common: typo like `app-configs` vs `app-config`.

**Secret values:** Always decode to check: `kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d`. Watch for double-encoding.

#### Likely fixes

**Missing ConfigMap or Secret:** Find expected name from deployment spec. Create: `kubectl create configmap <cm> --from-literal=KEY=value -n <ns>` or `kubectl create secret generic <secret> --from-literal=KEY=value -n <ns>`.

**Wrong reference name in Deployment:** `kubectl edit deploy <deploy> -n <ns>` — correct `envFrom[].configMapRef.name` or `secretRef.name`.

**Wrong volume mount path:** `kubectl edit deploy <deploy> -n <ns>` — correct `volumeMounts[].mountPath`. Verify: `kubectl exec <pod> -n <ns> -- ls <path>`.

After any config change, pods must be restarted to pick up new values:

```bash
kubectl rollout restart deploy/<deploy> -n <ns>
```

#### Verify

```bash
kubectl describe pod <pod> -n <ns>          # no Warning events about missing objects
kubectl exec <pod> -n <ns> -- env | grep <KEY>   # correct values injected
kubectl logs <pod> -n <ns>                  # clean startup
```

---

<a id="resource-scheduling"></a>
### Resource / Scheduling / Storage

**Start here if** pod is `Pending`, exit code is 137 (OOMKilled), or PVC is stuck in `Pending`.

Say: *"The pod is [Pending / OOMKilled / has a storage issue]. Let me find the specific constraint that's blocking it."*

#### Pending pods

```bash
kubectl describe pod <pod> -n <ns>
kubectl describe node | grep -A 5 Allocatable
kubectl top nodes
```

Read the Events section. The scheduler message names the exact blocker:

| Event message | Cause | Fix |
|---|---|---|
| `Insufficient cpu` / `Insufficient memory` | Requests exceed node capacity | Lower requests: `kubectl edit deploy <deploy> -n <ns>` |
| `no nodes available to schedule` | Taint/affinity/selector mismatch | Check taints: `kubectl describe node`, fix tolerations or remove nodeSelector |
| `unbound immediate PersistentVolumeClaim` | PVC can't bind | See Storage section below |

**Compare** pod requests against node allocatable:

```bash
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].resources.requests}'
kubectl describe node | grep -A 5 Allocatable
```

If requests exceed allocatable, the pod can never schedule.

#### OOMKilled (exit 137)

```bash
kubectl describe pod <pod> -n <ns>    # check Last State for OOMKilled
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].resources.limits.memory}'
kubectl top pod <pod> -n <ns>         # if metrics available
```

Fix: `kubectl edit deploy <deploy> -n <ns>` — increase `resources.limits.memory`. Don't raise blindly — confirm usage is near the limit first.

#### Storage (PVC issues)

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get storageclass
kubectl get pv
```

**PVC STATUS column:** `Bound` = healthy. `Pending` = no PV matched.

**PVC Events** name the exact failure:

| Event message | Cause | Fix |
|---|---|---|
| `no persistent volumes available` | No matching PV/StorageClass | Check `storageClassName` on PVC vs available StorageClasses |
| `storageclass "X" not found` | PVC references nonexistent class | Fix or create the StorageClass |
| Capacity mismatch | PV too small for PVC request | Adjust capacity |
| Access mode mismatch | e.g., PVC wants `ReadWriteMany`, PV offers `ReadWriteOnce` | Fix access modes |

**Compare:** `kubectl get pvc <pvc> -n <ns> -o jsonpath='{.spec.storageClassName}'` vs `kubectl get storageclass` NAME column.

PVC fields are mostly immutable — delete and recreate:

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

**Wrong volume mount path:** `kubectl edit deploy <deploy> -n <ns>` — correct `volumeMounts[].mountPath`.

#### Verify

```bash
kubectl get pvc -n <ns>       # Bound
kubectl get pods -n <ns>      # Running, Ready
curl -s localhost/health      # 200
```

---

<a id="service-routing"></a>
### Service Routing / Ports / Endpoints

**Start here if** pods are Running and Ready but the app is unreachable through the Service.

Say: *"Pods are Running and Ready, but I can't reach the app through the Service. I need to check selectors, endpoints, and ports."*

#### Commands

```bash
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/
```

#### What the output usually implies

**Endpoints:** This is the single most decisive check. Healthy: `10.244.x.x:8000` (pod IPs). Broken: `<none>` — Service selector matches zero Ready pods.

**Selector mismatch:** Compare `kubectl describe svc <svc>` Selector field exactly against `kubectl get pods --show-labels` LABELS column. Any character difference means no match: `app=api` vs `app=platform-drill-api`.

**Wrong targetPort:** `kubectl describe svc <svc>` shows Port and TargetPort. The TargetPort must match the container's listening port. Find it: `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].ports[0].containerPort}'`.

**Pods not Ready = empty endpoints:** Even if the selector matches, only `1/1` Ready pods appear in endpoints. If pods show `0/1`, fix readiness first → [Probe Failure](#probe-failure).

**Port-forward test:** If `kubectl port-forward svc/<svc>` + curl succeeds but `curl localhost/` fails → problem is Ingress or NetworkPolicy, not Service.

#### Likely fixes

**Selector mismatch:**

```bash
kubectl patch svc <svc> -n <ns> -p '{"spec":{"selector":{"app":"<correct-label>"}}}'
```

**Wrong targetPort:**

```bash
kubectl patch svc <svc> -n <ns> -p '{"spec":{"ports":[{"port":<svc-port>,"targetPort":<correct-port>}]}}'
```

#### Verify

```bash
kubectl get endpoints <svc> -n <ns>     # pod IPs populated
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl -i localhost:8080/                  # valid response
curl -s localhost/                       # end-to-end through Ingress
```

Do not stop at port-forward. The external curl proves the full path.

---

<a id="dns-namespace"></a>
### DNS / Namespace / Service Discovery

**Start here if** resources appear to be missing entirely, DNS resolution fails, or pods can't resolve service hostnames.

#### Namespace confusion

Say: *"I'm not seeing the resources I expect. Let me check if they're in a different namespace."*

```bash
kubectl get all -A
kubectl get ns
kubectl config view --minify | grep namespace
```

Look for: resources in `default` or a similarly-named but wrong namespace. Compare NAMESPACE column against where your commands are targeting.

**Fix wrong default namespace:** `kubectl config set-context --current --namespace=<correct-ns>`

**Resources in wrong namespace:** Export, change `metadata.namespace`, re-apply, delete from wrong namespace.

**Cross-namespace reference:** Use FQDN: `<service>.<namespace>.svc.cluster.local`

#### DNS resolution failures

If a pod shows `Name or service not known` in logs:

```bash
kubectl exec <pod> -n <ns> -- nslookup <hostname>
kubectl get svc -n <ns>
```

Compare the hostname the app is using against actual Service names. If DNS itself is broken (can't resolve any name), check:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get networkpolicy -n <ns>
```

A missing DNS egress NetworkPolicy will silently break all name resolution → [NetworkPolicy](#networkpolicy).

#### Verify

```bash
kubectl get all -n <correct-ns>
kubectl exec <pod> -n <ns> -- nslookup <service>
```

---

<a id="ingress"></a>
### Ingress / External Routing

**Start here if** the Service works via port-forward but the external URL fails.

Say: *"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer."*

**Important:** If Service/endpoints are broken, go to [Service Routing](#service-routing) first. Do not blame Ingress when the chain underneath is broken.

#### Commands

```bash
kubectl get ingress -n <ns>
kubectl describe ingress <ing> -n <ns>
kubectl get ingressclass
kubectl get pods -n ingress-nginx
```

#### What the output usually implies

**ADDRESS column:** Healthy: an IP or `localhost`. Blank = ingress controller hasn't admitted this resource (wrong IngressClass or controller not running).

**IngressClass:** Must match installed controller. `kubectl get ingressclass` shows what's available.

**Rules > Backends:** Backend service name and port must match an existing Service. The ingress backend port must match the service `port:`, not the `targetPort:`. Compare: `kubectl get svc <svc> -n <ns> -o jsonpath='{.spec.ports[0].port}'`.

**Host and Path:** If `Host:` is set, requests need a matching Host header. `pathType: Exact` with `/api` won't match `/`.

**Controller health:** `kubectl get pods -n ingress-nginx` — must be Running and Ready.

#### Likely fixes

**Wrong backend port:**

```bash
kubectl patch ingress <ing> -n <ns> --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":<correct-port>}]'
```

**Wrong backend service name:**

```bash
kubectl patch ingress <ing> -n <ns> --type=json \
  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"<correct-svc>"}]'
```

**Wrong IngressClass:** `kubectl patch ingress <ing> -n <ns> -p '{"spec":{"ingressClassName":"nginx"}}'`

**Controller not running:** `kubectl rollout restart deploy/ingress-nginx-controller -n ingress-nginx`

#### Verify

```bash
kubectl get ingress -n <ns>       # ADDRESS populated
kubectl describe ingress <ing> -n <ns>   # Backends show correct service with endpoints
curl -s localhost/
curl -s localhost/health
```

---

<a id="networkpolicy"></a>
### NetworkPolicy / Traffic Restriction

**Start here if** everything looks correct — pods Running, Ready, endpoints populated, services exist — but traffic silently fails or times out. No error messages, just no response.

Say: *"Everything looks healthy but traffic is failing silently. When all the obvious things check out, it's often a NetworkPolicy blocking traffic."*

#### Commands

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
kubectl get pods -n <ns> --show-labels
```

#### What the output usually implies

**POD-SELECTOR column:** `<none>` means empty `podSelector: {}` — applies to ALL pods in the namespace.

**Policy Types:**
- `Ingress` listed = inbound traffic not explicitly allowed is denied
- `Egress` listed = outbound traffic not explicitly allowed is denied

**Common broken patterns:**
- Allow rule `podSelector` doesn't match any running pods (label typo)
- Allow rule `namespaceSelector` wrong — for ingress-nginx traffic, need `kubernetes.io/metadata.name: ingress-nginx`
- Missing port specification in allow rule
- No DNS egress rule — pods can't resolve hostnames, producing silent connection failures
- Egress deny exists but no rule allowing app-to-database traffic

#### Quick test

Delete policies one at a time and test after each:

```bash
kubectl get networkpolicy -n <ns> -o name
kubectl delete networkpolicy <policy-name> -n <ns>
curl localhost/
```

If traffic works after deleting a specific policy, that was the blocker. Re-apply a corrected version.

#### Likely fixes

**Wrong podSelector in allow rule:** `kubectl edit networkpolicy <policy> -n <ns>` — fix `podSelector.matchLabels` to match actual pod labels.

**Missing allow rule (e.g., app-to-database egress):**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-db
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

**Missing DNS egress rule:**

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

#### Verify

```bash
kubectl get networkpolicy -n <ns>
curl -s localhost/
curl -s localhost/health
```

All policies present, all requests return expected data.

---

<a id="deployment-rollout"></a>
### Deployment / Rollout

**Start here if** the deployment exists but new pods aren't appearing or the rollout seems stuck, and pods are not in an obviously broken state.

Say: *"The deployment exists but new pods aren't appearing or the rollout seems stuck. Let me check rollout status and ReplicaSets."*

#### Commands

```bash
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl get deploy -n <ns>
kubectl describe deploy <deploy> -n <ns>
kubectl rollout history deploy/<deploy> -n <ns>
```

#### What the output usually implies

**Rollout status:** `successfully rolled out` = healthy. `Waiting for deployment rollout to finish` = stuck.

**ReplicaSets:** Old RS `1 1 1`, new RS `1 1 0` = new pods never became Ready, old RS still serving.

**Describe deploy — Conditions:** `ProgressDeadlineExceeded` = rollout timed out.

Check the new RS's pods for a clear status. If `ImagePullBackOff` → [Image Pull](#image-pull). If `CrashLoopBackOff` → [Startup / Crash](#startup-crash). If `0/1` Ready → [Probe Failure](#probe-failure).

#### Likely fixes

**Bad image tag:** `kubectl set image deploy/<deploy> <container>=<correct-image>:<tag> -n <ns>`

**Rollback:** `kubectl rollout undo deploy/<deploy> -n <ns>` (or `--to-revision=<N>`)

**Bad config in new template:** Fix the ConfigMap/Secret, then `kubectl rollout restart deploy/<deploy> -n <ns>`

#### Verify

```bash
kubectl rollout status deploy/<deploy> -n <ns>    # successfully rolled out
kubectl get rs -n <ns>                             # one RS at desired count
kubectl get pods -n <ns>                           # all Running 1/1
```

---

<a id="app-failure"></a>
### Application-Level Failure

**Start here if** pods are Running and Ready, endpoints are populated, but the app returns 5xx errors or wrong responses. Kubernetes thinks everything is fine.

Say: *"Everything looks healthy from a Kubernetes perspective — pods Running, Ready, endpoints populated. So this is an application-level issue. Logs should tell me what's going on."*

#### Commands

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl exec <pod> -n <ns> -- env | sort
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d
```

#### What the output usually implies

| Log message | Cause | How to find correct value |
|---|---|---|
| `connection refused` to DB host | Wrong hostname or DB not running | `kubectl get svc -n <ns>` — Service NAME = correct hostname |
| `password authentication failed` | Wrong credentials | Compare decoded Secret against authoritative source |
| `database "X" does not exist` | Wrong DB name in config | Compare pod env against Postgres ConfigMap |
| `relation "X" does not exist` | Schema not initialized | App may need restart after config fix |
| `Name or service not known` | DNS can't resolve hostname | `kubectl get svc -n <ns>` — use exact Service name |
| App returns 404 on expected paths | Wrong base path or route config | Check env vars for `BASE_PATH`/`ROOT_PATH`; check startup logs for registered routes |

**Diagnostic pattern:** (1) `kubectl exec <pod> -- env | sort` to see runtime values, (2) compare each value against the authoritative source — `kubectl get svc` for hostnames, ConfigMap for DB name/user, decoded Secret for passwords. Mismatches between runtime env and what actually exists = root cause.

#### Likely fixes

**Wrong ConfigMap value:** `kubectl edit configmap <cm> -n <ns>`, then `kubectl rollout restart deploy/<deploy> -n <ns>`.

**Wrong Secret value:** `kubectl edit secret <secret> -n <ns>` (values must be base64-encoded), then `kubectl rollout restart deploy/<deploy> -n <ns>`.

**Schema not initialized:** `kubectl rollout restart deploy/<deploy> -n <ns>` — if the app runs migrations on startup, a clean restart after fixing config may resolve it.

#### Verify

```bash
kubectl logs <pod> -n <ns>                   # no connection or auth errors
kubectl exec <pod> -n <ns> -- env | sort     # env vars correct
curl -s localhost/health                     # 200
curl -s localhost/<known-app-path>           # expected data
```

---

<a id="jobs-cronjobs"></a>
### Jobs / CronJobs

**Start here if** the scenario involves batch or scheduled work.

Say: *"This is a Job or CronJob issue. I need to check whether the job itself is misconfigured or if the pods it creates are failing."*

#### Commands

```bash
kubectl get jobs -n <ns>
kubectl get cronjobs -n <ns>
kubectl describe job <job> -n <ns>
kubectl describe cronjob <cj> -n <ns>
kubectl get pods -n <ns> --selector=job-name=<job>
kubectl logs <job-pod> -n <ns>
```

#### What the output usually implies

**Job COMPLETIONS:** `1/1` = healthy. `0/1` after sufficient time = pod is failing.

**Events:** `BackoffLimitExceeded` = Job exhausted retries, won't retry further.

**CronJob SUSPEND:** `True` = paused, won't fire. **LAST SCHEDULE:** `<none>` = bad schedule syntax, never fires.

**Schedule field:** Must be valid 5-field cron (e.g., `*/5 * * * *`). Kubernetes accepts invalid syntax silently.

#### Likely fixes

**Pod failing:** Fix the root cause ([Startup / Crash](#startup-crash) or [Config Injection](#config-injection)), then delete and recreate the Job (Jobs are immutable after creation).

**CronJob suspended:** `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"suspend":false}}'`

**Bad schedule syntax:** `kubectl patch cronjob <cj> -n <ns> -p '{"spec":{"schedule":"<correct-cron>"}}'`

**Test immediately:** `kubectl create job <job>-test --from=cronjob/<cj> -n <ns>`

#### Verify

```bash
kubectl get jobs -n <ns>                              # COMPLETIONS 1/1
kubectl get pods --selector=job-name=<job> -n <ns>    # Completed
kubectl logs <job-pod> -n <ns>                        # clean output
```

---

<a id="quick-reference"></a>
## Quick Reference

```bash
# Orientation
kubectl config current-context
kubectl get ns
kubectl get all -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp

# Pod diagnostics
kubectl describe pod <pod> -n <ns>
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
kubectl logs <pod> -c <container> -n <ns>
kubectl exec <pod> -n <ns> -- env | sort

# Service diagnostics
kubectl get endpoints <svc> -n <ns>
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels

# Config diagnostics
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

# Network diagnostics
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>

# Deployment diagnostics
kubectl rollout status deploy/<deploy> -n <ns>
kubectl get rs -n <ns>

# Storage diagnostics
kubectl get pvc -n <ns>
kubectl get storageclass

# RBAC diagnostics
kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> <verb> <resource> -n <ns>

# Common fixes
kubectl edit deploy <deploy> -n <ns>
kubectl set image deploy/<deploy> <container>=<image>:<tag> -n <ns>
kubectl rollout restart deploy/<deploy> -n <ns>
kubectl rollout undo deploy/<deploy> -n <ns>
kubectl patch svc <svc> -n <ns> -p '<json>'

# Reachability testing
kubectl port-forward pod/<pod> 8080:<port> -n <ns>
kubectl port-forward svc/<svc> 8080:<port> -n <ns>
curl -s localhost/
curl -s localhost/health
```

---

<a id="appendix-exit-codes"></a>
## Appendix A: Exit Codes and Pod Statuses

### Container Exit Codes

| Code | Meaning | Typical cause | Next step |
|---|---|---|---|
| 0 | Success | Normal for init containers and Jobs | Unexpected for long-running apps — check command/args |
| 1 | Application error | Unhandled exception, config error | `kubectl logs --previous` → [Startup / Crash](#startup-crash) |
| 2 | Shell builtin misuse | Bad command syntax in spec | Check `command`/`args` |
| 126 | Not executable | Wrong permissions | Check image |
| 127 | Command not found | Binary missing from image | Check image contents |
| 137 | OOMKilled (128+9) | Exceeded memory limit | [Resource / Scheduling](#resource-scheduling) |
| 139 | Segfault (128+11) | App bug or corrupt binary | Check image |
| 143 | SIGTERM (128+15) | Normal shutdown or liveness kill | If unexpected: [Probe Failure](#probe-failure) |

### Pod Statuses

| Status | Meaning | Next step |
|---|---|---|
| Running | Containers started | Check READY column — `0/1` → [Probe Failure](#probe-failure) |
| Pending | Not scheduled | `kubectl describe pod` → [Resource / Scheduling](#resource-scheduling) |
| CrashLoopBackOff | Repeated crashes | → [Startup / Crash](#startup-crash) |
| ImagePullBackOff / ErrImagePull | Image pull failed | → [Image Pull](#image-pull) |
| OOMKilled | Memory limit exceeded | → [Resource / Scheduling](#resource-scheduling) |
| Init:0/1 / Init:CrashLoopBackOff | Init container failing | → [Startup / Crash](#startup-crash) (init section) |
| Completed | Exited cleanly | Normal for Jobs, unexpected for Deployments |
| ContainerCreating | Pulling image or mounting volume | If stuck: check events |

### Common Event Reasons

| Reason | Meaning | Next step |
|---|---|---|
| FailedScheduling | No suitable node | → [Resource / Scheduling](#resource-scheduling) |
| FailedMount | Volume can't mount | → [Resource / Scheduling](#resource-scheduling) or [Config Injection](#config-injection) |
| Unhealthy | Probe failed | → [Probe Failure](#probe-failure) |
| Killing | Container killed | If unexpected: [Probe Failure](#probe-failure) |
| BackOff | Backing off restart/pull | → [Startup / Crash](#startup-crash) or [Image Pull](#image-pull) |
| Forbidden | RBAC denied | → [RBAC](#rbac) |
| FailedCreate | RS can't create pod | → [Deployment / Rollout](#deployment-rollout) |

---

<a id="appendix-http"></a>
## Appendix B: HTTP Status Codes

| Code | Meaning | Interview context |
|---|---|---|
| 200 | OK | Expected healthy response |
| 404 | Not Found | Wrong probe path → [Probe Failure](#probe-failure). Wrong Ingress path → [Ingress](#ingress) |
| 500 | Internal Server Error | App crash — check logs → [Application-Level](#app-failure) |
| 502 | Bad Gateway | Proxy got invalid response — check endpoints, pod readiness → [Service Routing](#service-routing) |
| 503 | Service Unavailable | No healthy backend — check readiness, selector, endpoints → [Service Routing](#service-routing) |
| 504 | Gateway Timeout | Upstream too slow — check app performance, resource limits → [Application-Level](#app-failure) |
| 403 | Forbidden | Auth issue — check RBAC → [RBAC](#rbac) |
