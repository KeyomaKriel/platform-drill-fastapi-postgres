# Troubleshooting Routing Tree

Generic branching skeleton for repo-based Kubernetes troubleshooting interviews.
Every path ends at a root-cause domain or loops back to a higher node.

---

## Rule 0

Do not guess. Start from the visible symptom, the nearest object, and the fastest truth-revealing command.

**Symptom first, root cause second.** Pod status, HTTP codes, error strings, and timeouts are symptoms. The root-cause domain is what you route *to* — never where you start.

---

## Node 1 — Repo-First Orientation

Before touching the cluster, build a mental model from the repo.

```
READ repo
  |
  +-- App entrypoint ---- endpoints, startup logic, dependencies, failure behaviour
  +-- Config / env ------- which vars, required vs optional, source (ConfigMap/Secret)
  +-- Dockerfile --------- base image, exposed port, startup command
  +-- K8s manifests ------ Deployments, Services, Ingress, probes, env injection, policies
  +-- Deploy path -------- raw manifests / Helm / Kustomize / scripts
  |
  v
Mental model: what "healthy" looks like, what could break, how changes get applied
```

Then proceed to the cluster.

---

## Node 2 — Entry Mode Selection

```
What do you know?
  |
  +-- Scope unclear / multiple things may be broken
  |     -> FULL TRIAGE
  |        context -> namespaces -> pods -A -> deploys -> services -> ingress -> events
  |        Goal: find the target namespace and first signal, then commit
  |
  +-- Known app + known symptom + unknown cause
        -> FAST PATH
           pods -> describe pod -> logs -> test reachability layer by layer
```

Either mode feeds into Node 3. Full triage narrows to fast path once a signal appears.

---

## Node 3 — Pod State Check

```
kubectl get pods -n <ns>

Read: STATUS, READY, RESTARTS
  |
  +-- Pods NOT healthy -----------> Node 4  (classify pod symptom)
  |
  +-- Pods healthy (Running, Ready, low restarts) --> Node 5  (reachability path)
  |
  +-- No pods exist at all -------> Check: Deployment exists? Replicas > 0? Namespace correct?
                                     -> if Deployment missing/wrong namespace:
                                          DNS / Namespace
                                     -> if Deployment exists but 0 replicas or rollout stuck:
                                          Deployment / Rollout (see Node 6)
```

---

## Node 4 — Classify Pod Symptom

Pod symptom is **not** the root cause. It tells you where to look next.

```
Pod STATUS / condition
  |
  +-- ImagePullBackOff / ErrImagePull / ErrImageNeverPull
  |     -> ROOT CAUSE: Image Pull / Container Creation
  |
  +-- CreateContainerConfigError / CreateContainerError
  |     -> ROOT CAUSE: Image Pull / Container Creation
  |        (often a missing ConfigMap/Secret reference — check describe pod Events)
  |        May reroute to: Config / Secret / Env
  |
  +-- Pending (not scheduling)
  |     -> ROOT CAUSE: Resource / Scheduling / Storage
  |        Check: insufficient CPU/memory, node affinity, taints, PVC pending
  |
  +-- CrashLoopBackOff / Error / Init:CrashLoopBackOff / Init:Error
  |     -> SYMPTOM HUB — does not name the root cause by itself
  |        -> Node 4a  (log-based routing)
  |
  +-- Running but NOT Ready (0/1)
  |     -> ROOT CAUSE: Probe Failure (readiness)
  |        Confirm: describe pod -> check probe config, target path/port
  |        May reroute to: App-Level Failure if probe path is correct but app is unhealthy
  |
  +-- Running, Ready, but RESTARTS climbing
        -> ROOT CAUSE: Probe Failure (liveness) or Startup / Crash
           Check: describe pod Last State, exit code, liveness probe config
```

---

### Node 4a — CrashLoopBackOff Log Routing

CrashLoopBackOff tells you *where to start*. Logs tell you the *root-cause branch*.

```
kubectl describe pod <pod>     -- State, Last State, exit codes, Events
kubectl logs <pod>             -- current attempt
kubectl logs <pod> --previous  -- last crashed attempt
kubectl logs <pod> -c <init>   -- init container if Init:* status

Read the log output:
  |
  +-- Missing ConfigMap / Secret / key reference error
  |     -> ROOT CAUSE: Config / Secret / Env
  |
  +-- Wrong env value (bad hostname, wrong DB name, wrong password)
  |     -> ROOT CAUSE: Config / Secret / Env
  |
  +-- "Name or service not known" / DNS resolution failure
  |     -> ROOT CAUSE: DNS / Service Discovery / Namespace
  |        (cross-check: is the hostname value itself wrong? -> may be Config / Secret / Env)
  |
  +-- Connection refused / connection timed out to dependency
  |     -> ROOT CAUSE: App-Level Dependency / Runtime
  |        (cross-check: is the host/port value wrong? -> may be Config / Secret / Env)
  |
  +-- Auth failure to dependency (wrong credentials)
  |     -> ROOT CAUSE: Config / Secret / Env  or  App-Level Dependency / Runtime
  |
  +-- OOMKilled / exit code 137
  |     -> ROOT CAUSE: Resource / Scheduling / Storage
  |
  +-- Exit code 1 with app-specific error (unhandled exception, missing module, bad syntax)
  |     -> ROOT CAUSE: Startup / Crash
  |
  +-- Command not found / exec format error / bad entrypoint
  |     -> ROOT CAUSE: Image Pull / Container Creation  or  Startup / Crash
  |
  +-- App starts but is killed by probes (healthy start, then SIGTERM)
  |     -> ROOT CAUSE: Probe Failure
  |
  +-- Forbidden / permission denied on K8s API call
        -> ROOT CAUSE: RBAC / Service Account / Permission
```

**Key principle:** When the log names a missing or wrong *value*, the root cause is usually Config / Secret / Env — even if the symptom looks like a connectivity or dependency issue.

---

## Node 5 — Reachability Path (Pods Healthy)

Test layer by layer. Stop at the first layer that fails.

```
A. Test Pod directly
   kubectl port-forward pod/<pod> 8080:<container-port>
   curl -i localhost:8080/
     |
     +-- Pod does not respond
     |     -> ROOT CAUSE: App-Level Dependency / Runtime
     |        (app is running but broken — check logs, env vars)
     |        May reroute to: Config / Secret / Env
     |
     +-- Pod responds -> continue to B

B. Test Service / Endpoints
   kubectl get endpoints <svc>
   kubectl port-forward svc/<svc> 8080:<svc-port>
   curl -i localhost:8080/
     |
     +-- Endpoints empty (no backend IPs)
     |     -> ROOT CAUSE: Service Routing / Port / Endpoint
     |        (selector mismatch or pods not Ready)
     |        May reroute to: Probe Failure if readiness is the real reason
     |
     +-- Endpoints populated but port-forward fails or wrong response
     |     -> ROOT CAUSE: Service Routing / Port / Endpoint
     |        (port/targetPort mismatch)
     |
     +-- Service responds -> continue to C

C. Test Ingress / External Path
   curl -i localhost/
     |
     +-- Returns error or wrong backend
     |     -> ROOT CAUSE: Ingress / External Routing
     |        (wrong path rule, wrong backend service/port, wrong ingressClass)
     |
     +-- Times out silently (no error, no response)
     |     -> ROOT CAUSE: NetworkPolicy / Traffic Restriction
     |        (ingress controller -> app traffic blocked, or app -> dependency blocked)
     |
     +-- Works -> system is healthy end-to-end
```

---

## Node 6 — Special Entry Points

These symptoms don't follow the main pod-state -> reachability flow. They route directly.

```
Symptom observed
  |
  +-- Forbidden / Unauthorized / "cannot <verb> <resource>"
  |     -> ROOT CAUSE: RBAC / Service Account / Permission
  |     Check: ServiceAccount, Role, RoleBinding chain
  |
  +-- Resources appear to be missing entirely
  |     -> Check namespace: kubectl get <resource> -A
  |     -> ROOT CAUSE: DNS / Service Discovery / Namespace (namespace confusion)
  |
  +-- PVC stuck in Pending / volume mount error
  |     -> ROOT CAUSE: Resource / Scheduling / Storage
  |
  +-- Deployment exists, pods don't (or old pods still running)
  |     -> Rollout stuck or failed
  |     -> Check new ReplicaSet's pods — route their symptoms through Node 4
  |     (Rollout is a *view* into the problem, not a root cause by itself)
  |
  +-- Pods Running + Ready but app returns 5xx
        -> ROOT CAUSE: App-Level Dependency / Runtime
        (app is serving but a dependency is down or misconfigured)
```

---

## Node 7 — Fix

```
Root cause identified
  |
  +-- Apply the smallest justified fix
  |     Change ONE thing for ONE reason.
  |     Do not shotgun multiple edits.
  |
  +-- Follow the correct deploy path (identified in Node 1)
  |     Code/config change -> rebuild image -> load into cluster -> apply manifests
  |     Manifest-only change -> kubectl apply
  |     kubectl patch / set for runtime-only cluster fix
  |
  v
Node 8 — Verify
```

---

## Node 8 — End-to-End Verification

Do not stop at "pods are Running."

```
After any fix, verify in order:
  |
  1. Pod state healthy (Running, Ready, no new restarts)
  2. Endpoints populated for all services
  3. Pod responds (port-forward test)
  4. Service responds (port-forward test)
  5. Ingress / external path responds
  6. App returns expected responses (all known endpoints)
  |
  +-- All pass -> done
  +-- Any fail -> return to Node 3 with new symptom
```

---

## Root-Cause Domain Index

The 11 root-cause domains this tree routes to. Every terminal branch above points to one of these.

| # | Domain | Typical entry signals |
|---|--------|---------------------|
| 1 | Startup / Crash | CrashLoopBackOff + logs show app error |
| 2 | Image Pull / Container Creation | ImagePullBackOff, ErrImagePull, CreateContainerError |
| 3 | Probe Failure | Running 0/1, restarts climbing, probe-related events |
| 4 | Config / Secret / Env | Missing ref, wrong value, env-driven crash |
| 5 | Service Routing / Port / Endpoint | Empty endpoints, port mismatch, selector mismatch |
| 6 | DNS / Service Discovery / Namespace | "Name or service not known", resources missing, wrong namespace |
| 7 | Resource / Scheduling / Storage | Pending, OOMKilled, PVC issues |
| 8 | Ingress / External Routing | Service works but external URL fails |
| 9 | NetworkPolicy / Traffic Restriction | Everything looks healthy but traffic silently drops |
| 10 | RBAC / Service Account / Permission | Forbidden, Unauthorized, can-i returns no |
| 11 | App-Level Dependency / Runtime | Pods healthy, app serves errors or doesn't respond |

---

## Compressed Interview Version

```
1. Repo-first orientation — build mental model before cluster
2. Choose entry mode — full triage (scope unclear) or fast path (known app)
3. Check pods — STATUS, READY, RESTARTS
4. If pods broken — classify symptom, route to domain
5. If CrashLoopBackOff — logs decide the real root cause
6. If pods healthy — test pod -> service -> ingress layer by layer
7. If traffic silently fails — think NetworkPolicy
8. If Forbidden/Unauthorized — think RBAC
9. Apply smallest justified fix — one change, one reason
10. Verify end-to-end — not just "pods Running"
```
