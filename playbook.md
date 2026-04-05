# Kubernetes Troubleshooting Playbook

Reference guide for systematic debugging during a hands-on Platform Engineer interview.

---

## Step 1 — Orient

Run these first, every time. No exceptions. Say: *"I'm going to start by getting the full picture of what's running in the cluster."*

```bash
kubectl config current-context
kubectl get ns
```

- set the default namespace for the current context if you want to stop repeating `-n`:

```bash
kubectl config set-context --current --namespace=<ns>
```

Once you know the namespace:

```bash
kubectl get all -n <ns>
kubectl get ingress -n <ns>
kubectl get networkpolicy -n <ns>
kubectl get pvc -n <ns>
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```

If you don't know the namespace or things look empty:

```bash
kubectl get all -A
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

Say: *"I'm checking across all namespaces in case resources are deployed somewhere unexpected."*

---

## Step 2 — Read the Signals

Look at the output from Step 1 and find the **strongest signal**. Commit to one bucket. Say: *"The strongest signal I'm seeing is [X], so I'm treating this as a [bucket] problem."*

| What you see | Bucket | Go to |
|---|---|---|
| Pod status: `Pending` | Resource constraints or storage | Section A |
| Pod status: `ImagePullBackOff` or `ErrImagePull` | Image / registry | Section B |
| Pod status: `CrashLoopBackOff` | Pod startup / app crash | Section C |
| Pod status: `Init:CrashLoopBackOff` or `Init:0/1` | Init container | Section D |
| Pod status: `Running` but READY shows `0/1` | Health probes (readiness) | Section E |
| Pod `Running` + `1/1` but RESTARTS climbing | Health probes (liveness) | Section F |
| All pods `Running` + `Ready` but can't reach app via Service | Service routing | Section G |
| Service works (port-forward OK) but external URL fails | Ingress | Section H |
| Pods `Running` + `Ready` but app returns 5xx errors | Application-level | Section I |
| Events show missing ConfigMap or Secret | Configuration injection | Section J |
| Deployment exists but new pods not appearing | Deployment / rollout | Section K |
| PVC stuck in `Pending` | Storage | Section L |
| Everything looks healthy but traffic silently times out | Network policies | Section M |
| Resources appear to be missing entirely | Namespace confusion | Section N |
| `Forbidden` or `Unauthorized` errors | RBAC | Section O |

If multiple signals compete, pick the one closest to the root. Pod issues before Service issues. Config issues before app crash issues.

---

## Section A — Pending Pod

Say: *"The pod is Pending, which means it hasn't been scheduled to a node. I want to find out why — it's usually either a resource constraint or a storage issue."*

### Diagnose

```bash
kubectl describe pod <pod> -n <ns>
```

Look at the **Events** section at the bottom. The message tells you exactly what's wrong.

| Event message | Cause | Fix |
|---|---|---|
| `Insufficient cpu` or `Insufficient memory` | Resource requests too high for available nodes | Lower the requests |
| `no nodes available to schedule` | No nodes match (taints, affinity, etc.) | Check node taints and pod tolerations |
| `unbound immediate PersistentVolumeClaim` | PVC can't bind | Go to Section L |

### Fix resource requests

```bash
kubectl edit deployment <deploy> -n <ns>
```

Find `resources.requests` and lower the values. Save and exit. The pod will be recreated automatically.

### Verify

```bash
kubectl get pods -n <ns> -w
```

Wait until the pod shows `Running` and `1/1`.

---

## Section B — ImagePullBackOff

Say: *"The pod can't pull its container image. I need to check whether it's a wrong image name, a wrong tag, or a registry access issue."*

### Diagnose

```bash
kubectl describe pod <pod> -n <ns>
```

Look at the **Events** section for the pull error. It usually says exactly what image it tried to pull and why it failed.

| Event message | Cause | Fix |
|---|---|---|
| `manifest unknown` or `not found` | Wrong image name or tag | Correct the image |
| `unauthorized` or `no basic auth credentials` | Private registry, no pull secret | Create/attach imagePullSecret |
| `dial tcp: lookup ... no such host` | Registry hostname wrong | Correct the image URL |

### Fix wrong image

```bash
kubectl set image deployment/<deploy> <container-name>=<correct-image>:<tag> -n <ns>
```

If you don't know the container name:

```bash
kubectl get deployment <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[*].name}'
```

### Fix missing pull secret

```bash
kubectl create secret docker-registry <secret-name> \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <ns>

kubectl patch deployment <deploy> -n <ns> \
  -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"<secret-name>"}]}}}}'
```

### Verify

```bash
kubectl get pods -n <ns> -w
```

---

## Section C — CrashLoopBackOff

Say: *"The container is starting and then crashing repeatedly. I need to check the logs to understand why it's crashing."*

### Diagnose

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --previous
```

If the pod has multiple containers:

```bash
kubectl logs <pod> -c <container-name> -n <ns>
```

Also check describe for the exit code:

```bash
kubectl describe pod <pod> -n <ns>
```

Look for `Last State` in the container status:

| Exit code | Meaning | Next step |
|---|---|---|
| `0` | Container exited successfully (shouldn't restart) | Check `restartPolicy`, command/args |
| `1` | Application error | Read the logs carefully |
| `137` | OOMKilled (out of memory) | Check resource limits — go to Section A approach but raise limits |
| `139` | Segfault | Image/binary issue |

### Common causes and fixes

**Bad command or args overriding the entrypoint:**

```bash
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 5 "command\|args"
```

If command/args are wrong, edit:

```bash
kubectl edit deployment <deploy> -n <ns>
```

**App crashes because of bad config (wrong DB host, credentials, etc.):**

Go to Section I.

**OOMKilled:**

```bash
kubectl edit deployment <deploy> -n <ns>
```

Raise `resources.limits.memory`.

### Verify

```bash
kubectl get pods -n <ns> -w
kubectl logs <pod> -n <ns>
```

---

## Section D — Init Container Failure

Say: *"I see `Init:0/1` which means there's an init container that hasn't completed. The main container won't start until it succeeds. Let me check the init container logs specifically."*

### Diagnose

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

### Common causes

| Symptom | Cause | Fix |
|---|---|---|
| Init container loops waiting for a service | Target service doesn't exist or is in wrong namespace | Create the missing service or fix the hostname |
| Init container can't connect to a port | NetworkPolicy blocking egress, or target pod not ready | Check NetworkPolicies (Section M) or target pod status |
| Init container exits with error | Bad command, wrong image, missing config | Read the logs, fix the command/image/config |

### Fix

Usually you need to fix whatever the init container is waiting on, not the init container itself. If it's waiting for postgres:

```bash
kubectl get svc -n <ns>
kubectl get pods -n <ns>
kubectl get networkpolicy -n <ns>
```

### Verify

```bash
kubectl get pods -n <ns> -w
```

Wait for init container to complete (`Init:0/1` → `PodInitializing` → `Running`).

---

## Section E — Readiness Probe Failing (Running but not Ready)

Say: *"The pod is Running but not Ready — which means the readiness probe is failing. The pod won't receive traffic from the Service until it passes. Let me check what the probe is doing."*

### Diagnose

```bash
kubectl describe pod <pod> -n <ns>
```

Look for:
- `Readiness probe failed` messages in Events
- The probe spec under `Containers: → Readiness:`
- The path, port, initialDelaySeconds, and periodSeconds

### Common causes

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong probe path | Probe path doesn't match an actual app endpoint | `kubectl edit deployment` and fix the path |
| Wrong probe port | Probe port doesn't match the container's listening port | `kubectl edit deployment` and fix the port |
| initialDelaySeconds too short | App takes longer to start than the probe allows | Increase initialDelaySeconds |
| App actually unhealthy | Probe is correct but app has a real problem | Check logs — go to Section I |

### Test the probe manually

```bash
kubectl exec <pod> -n <ns> -- curl -s http://localhost:<port><path>
```

Or if curl isn't in the container:

```bash
kubectl port-forward <pod> 8080:<port> -n <ns>
# In another terminal:
curl http://localhost:8080<path>
```

### Fix

```bash
kubectl edit deployment <deploy> -n <ns>
```

Find the readiness probe and correct the path, port, or timing.

### Verify

```bash
kubectl get pods -n <ns> -w
kubectl get endpoints <svc> -n <ns>
```

Once Ready shows `1/1`, endpoints should populate.

---

## Section F — Liveness Probe Killing the Container

Say: *"The pod is Running and shows Ready, but the restart count keeps going up. That means the liveness probe is periodically failing and Kubernetes is killing the container. I need to check if the probe is misconfigured or if the app is genuinely unhealthy."*

### Diagnose

```bash
kubectl describe pod <pod> -n <ns>
```

Look for `Liveness probe failed` in Events and check the probe spec.

Same diagnosis as Section E but focus on the liveness probe. Common pattern: the liveness probe endpoint is too slow under load, or the timeout is too short.

### Fix

```bash
kubectl edit deployment <deploy> -n <ns>
```

Options:
- Fix the probe path or port
- Increase `timeoutSeconds` (default is 1, often too short)
- Increase `periodSeconds`
- Increase `failureThreshold` (how many failures before kill)
- Increase `initialDelaySeconds` if the app needs more startup time

### Verify

```bash
kubectl get pods -n <ns> -w
```

Watch for a few minutes. Restart count should stop climbing.

---

## Section G — Service Routing Failure

Say: *"Pods are Running and Ready, but I can't reach the app through the Service. I need to check if the Service is actually routing to the pods — that means checking selectors, endpoints, and ports."*

### Diagnose

```bash
kubectl get endpoints <svc> -n <ns>
```

**If endpoints are empty:**

The Service selector doesn't match any pod labels.

```bash
kubectl describe svc <svc> -n <ns>
kubectl get pods -n <ns> --show-labels
```

Compare the `Selector:` field on the Service to the labels on the pods. They must match exactly.

**If endpoints are populated but you still can't connect:**

The port mapping is wrong.

```bash
kubectl describe svc <svc> -n <ns>
```

Check `Port:` and `TargetPort:`. The `TargetPort` must match the port the container is actually listening on.

### Test the Service directly

```bash
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
# In another terminal:
curl http://localhost:8080
```

If port-forward works, the issue is upstream (Ingress, NetworkPolicy). If it doesn't, the issue is the Service or pod.

### Fix selector mismatch

```bash
kubectl edit svc <svc> -n <ns>
```

Correct the selector to match the pod labels. Or fix the pod labels:

```bash
kubectl edit deployment <deploy> -n <ns>
```

Fix the labels under `spec.template.metadata.labels`.

### Fix port mismatch

```bash
kubectl edit svc <svc> -n <ns>
```

Correct `targetPort` to match the container's listening port.

### Verify

```bash
kubectl get endpoints <svc> -n <ns>
kubectl port-forward svc/<svc> 8080:<svc-port> -n <ns>
curl http://localhost:8080
```

---

## Section H — Ingress Failure

Say: *"I can reach the app through port-forward, so the Service and pods are fine. The problem is in the Ingress layer — something between the external URL and the Service."*

### Diagnose

```bash
kubectl describe ingress <ingress> -n <ns>
kubectl get ingress -n <ns>
```

Check:
- Does the Ingress have an `ADDRESS` assigned? If not, the Ingress controller may not be running.
- Does the backend service name and port match an actual Service?
- Are the path rules correct?
- Is the IngressClass set?

```bash
kubectl get ingressclass
kubectl get pods -n ingress-nginx
```

### Common causes

| What's wrong | How to tell | Fix |
|---|---|---|
| Wrong backend service name | Service name in Ingress doesn't match any Service in the namespace | `kubectl edit ingress` |
| Wrong backend port | Port in Ingress doesn't match the Service port | `kubectl edit ingress` |
| Missing IngressClass | No `ingressClassName` field or wrong value | `kubectl edit ingress` |
| Ingress controller not running | No pods in `ingress-nginx` namespace, no ADDRESS on Ingress | Deploy/fix the controller |
| Wrong path or pathType | Request path doesn't match the rule | `kubectl edit ingress` |

### Fix

```bash
kubectl edit ingress <ingress> -n <ns>
```

### Verify

```bash
curl -i http://localhost/
curl -i http://localhost/health
```

Or if using a hostname:

```bash
curl -i -H "Host: <hostname>" http://localhost/
```

---

## Section I — Application-Level Failure

Say: *"Everything looks healthy from a Kubernetes perspective — pods are Running, Ready, endpoints are populated. But the app is returning errors. This is an application-level issue. Logs should tell me what's going on."*

### Diagnose

```bash
kubectl logs <pod> -n <ns>
kubectl logs <pod> -n <ns> --tail=50
```

Look for connection errors, authentication failures, missing tables, etc.

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

### Common causes

| Log message | Cause | Fix |
|---|---|---|
| `connection refused` to DB host | Wrong hostname or DB not running | Check the hostname in ConfigMap, check DB pod status |
| `password authentication failed` | Wrong credentials | Fix the Secret |
| `database "X" does not exist` | Wrong database name in config | Fix the ConfigMap |
| `relation "X" does not exist` | DB schema not initialized | Check if init ran, check DB connectivity during startup |
| `Name or service not known` | DNS can't resolve the hostname | Check the service name, check if DB service exists |

### Fix

```bash
kubectl edit configmap <cm> -n <ns>
kubectl edit secret <secret> -n <ns>
```

After editing config, restart the pods to pick up the change:

```bash
kubectl rollout restart deployment/<deploy> -n <ns>
```

### Verify

```bash
kubectl get pods -n <ns> -w
kubectl logs <pod> -n <ns>
curl http://localhost/health
```

---

## Section J — Configuration Injection Failure

Say: *"I see events or pod errors about a missing ConfigMap or Secret. The pod can't start because it's trying to reference configuration that doesn't exist or is named wrong."*

### Diagnose

```bash
kubectl describe pod <pod> -n <ns>
```

Look in Events for messages like:
- `configmap "X" not found`
- `secret "X" not found`
- `couldn't find key "X" in ConfigMap`

Check what the Deployment references:

```bash
kubectl get deployment <deploy> -n <ns> -o yaml | grep -A 3 "configMapRef\|secretRef\|configMapKeyRef\|secretKeyRef\|volumes"
```

Check what actually exists:

```bash
kubectl get configmap -n <ns>
kubectl get secret -n <ns>
```

### Common causes

| Error | Cause | Fix |
|---|---|---|
| ConfigMap/Secret not found | Name typo in the Deployment, or resource doesn't exist | Create the missing resource or fix the reference |
| Key not found | The ConfigMap/Secret exists but the specific key doesn't | Add the key or fix the key name in the reference |
| `envFrom` vs `env` | Using `configMapRef` (loads all keys) but meant to use `configMapKeyRef` (loads one key), or vice versa | Edit the Deployment |

### Fix the reference

```bash
kubectl edit deployment <deploy> -n <ns>
```

Or create the missing resource:

```bash
kubectl create configmap <name> --from-literal=KEY=value -n <ns>
kubectl create secret generic <name> --from-literal=KEY=value -n <ns>
```

### Verify

```bash
kubectl get pods -n <ns> -w
kubectl exec <pod> -n <ns> -- env | grep <expected-var>
```

---

## Section K — Deployment / Rollout Stuck

Say: *"The Deployment exists and there's an old ReplicaSet with pods, but the new version isn't rolling out. I need to check the rollout status and see what's blocking it."*

### Diagnose

```bash
kubectl rollout status deployment/<deploy> -n <ns>
kubectl get rs -n <ns>
kubectl describe deployment <deploy> -n <ns>
```

Look at the ReplicaSets. A stuck rollout typically shows:
- Old RS: desired=1, ready=1
- New RS: desired=1, ready=0

Check the new RS's pods:

```bash
kubectl get pods -n <ns>
kubectl describe pod <new-pod> -n <ns>
```

The new pod usually has a clear error (ImagePullBackOff, CrashLoopBackOff, etc.) — go to the relevant section for that error.

### Quick rollback if needed

```bash
kubectl rollout undo deployment/<deploy> -n <ns>
```

### Fix forward

Fix the underlying issue (bad image, bad config, etc.) and the rollout will proceed automatically.

### Verify

```bash
kubectl rollout status deployment/<deploy> -n <ns>
kubectl get pods -n <ns>
```

Should show `successfully rolled out` and new pods Running.

---

## Section L — Storage (PVC Pending)

Say: *"I see a PVC stuck in Pending. That means it can't bind to a PersistentVolume. I need to check if there's a matching StorageClass and if the request is valid."*

### Diagnose

```bash
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
kubectl get pv
kubectl get storageclass
```

Look at the Events on the PVC for the reason.

### Common causes

| Event message | Cause | Fix |
|---|---|---|
| `no persistent volumes available` and no StorageClass | No default StorageClass, no matching PV | Create a StorageClass or PV |
| `storageclass "X" not found` | PVC requests a StorageClass that doesn't exist | Fix the StorageClass name in the PVC or create it |
| Capacity mismatch | PV exists but is too small | Create a larger PV or reduce the PVC request |
| Access mode mismatch | PVC asks for ReadWriteMany but PV only supports ReadWriteOnce | Fix the access mode |
| PV already bound | PV is bound to a different PVC | Create a new PV |

### Fix

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

You may also need to restart the pod that uses this PVC:

```bash
kubectl rollout restart deployment/<deploy> -n <ns>
```

### Verify

```bash
kubectl get pvc -n <ns>
kubectl get pods -n <ns> -w
```

PVC should show `Bound`. Pod should start.

---

## Section M — Network Policies

Say: *"Everything looks correct — pods are Running, Ready, endpoints are populated, but traffic is failing silently. When all the obvious things check out, it's often a NetworkPolicy blocking traffic. Let me check."*

### Diagnose

```bash
kubectl get networkpolicy -n <ns>
kubectl describe networkpolicy -n <ns>
```

Read each policy carefully. Check:
- `podSelector`: which pods does this policy apply to?
- `policyTypes`: is it Ingress, Egress, or both?
- `ingress` rules: who is allowed to send traffic TO the selected pods?
- `egress` rules: where are the selected pods allowed to send traffic?

### Quick test — temporarily remove all policies

If you suspect a NetworkPolicy but can't tell which one:

```bash
kubectl get networkpolicy -n <ns> -o name
```

Delete one at a time and test after each deletion to isolate which policy is causing the block:

```bash
kubectl delete networkpolicy <policy-name> -n <ns>
curl http://localhost/
```

### Common causes

| Symptom | Likely cause | Fix |
|---|---|---|
| App can't reach database | Missing egress rule from app to DB, or missing ingress rule on DB from app | Add the appropriate allow rule |
| External traffic can't reach app | Default deny with no ingress rule allowing traffic from Ingress controller namespace | Add ingress rule with `namespaceSelector` matching the Ingress controller's namespace |
| DNS resolution fails | Egress to kube-system blocked, preventing DNS lookups | Add egress rule allowing traffic to kube-system on port 53 (TCP and UDP) |

### Fix — create an allow rule

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

### Verify

```bash
curl http://localhost/
kubectl exec <app-pod> -n <ns> -- curl -s http://<svc>:<port>
```

---

## Section N — Namespace Confusion

Say: *"I'm not seeing the resources I expect. Let me check if they're deployed to a different namespace."*

### Diagnose

```bash
kubectl get all -A
kubectl get ns
```

Look for resources in an unexpected namespace. Common variant: there are two similarly named namespaces and resources are split between them.

### Fix

Either move the resources (delete and recreate in the correct namespace) or update references to point to the right namespace.

To reference a service in a different namespace:

```
<service-name>.<namespace>.svc.cluster.local
```

### Verify

```bash
kubectl get all -n <correct-ns>
```

---

## Section O — RBAC

Say: *"I'm seeing Forbidden errors, which means the ServiceAccount doesn't have permission to perform this action. I need to check the Role and RoleBinding."*

### Diagnose

Test what the ServiceAccount can do:

```bash
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<ns>:<sa-name> \
  -n <ns>
```

Common verbs: `get`, `list`, `watch`, `create`, `update`, `delete`.

Check what's configured:

```bash
kubectl get sa -n <ns>
kubectl get role -n <ns>
kubectl get rolebinding -n <ns>
kubectl describe rolebinding <binding> -n <ns>
kubectl describe role <role> -n <ns>
```

### Common causes

| What's wrong | How to tell | Fix |
|---|---|---|
| ServiceAccount doesn't exist | `kubectl get sa -n <ns>` doesn't show it | Create it |
| Role missing a verb or resource | `kubectl describe role` shows insufficient permissions | Edit the Role |
| RoleBinding points to wrong SA or Role | `kubectl describe rolebinding` shows wrong subject or roleRef | Recreate the RoleBinding (roleRef is immutable) |
| Using Role but need ClusterRole | Action requires cluster-wide access | Create a ClusterRole and ClusterRoleBinding |

### Fix — create missing RBAC

```bash
kubectl create serviceaccount <sa-name> -n <ns>

kubectl create role <role-name> \
  --verb=get,list,watch \
  --resource=pods,services \
  -n <ns>

kubectl create rolebinding <binding-name> \
  --role=<role-name> \
  --serviceaccount=<ns>:<sa-name> \
  -n <ns>
```

**Important:** You can't edit the `roleRef` on a RoleBinding. You must delete and recreate it.

```bash
kubectl delete rolebinding <binding-name> -n <ns>
kubectl create rolebinding <binding-name> \
  --role=<correct-role> \
  --serviceaccount=<ns>:<sa-name> \
  -n <ns>
```

### Verify

```bash
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<ns>:<sa-name> \
  -n <ns>
```

Should return `yes`.

---

## After Every Fix

Always do this. Say: *"I've applied the fix. Now I'm going to verify end-to-end to make sure the issue is fully resolved."*

```bash
# Check pods are healthy
kubectl get pods -n <ns>

# Check endpoints are populated
kubectl get endpoints -n <ns>

# Test the app end-to-end
curl http://localhost/
curl http://localhost/health
curl http://localhost/items
```

If using port-forward instead of Ingress:

```bash
kubectl port-forward svc/<svc> 8080:<port> -n <ns>
# In another terminal:
curl http://localhost:8080/
curl http://localhost:8080/health
```

---

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

# Service diagnostics
kubectl describe svc <svc> -n <ns>
kubectl get endpoints <svc> -n <ns>
kubectl get pods -n <ns> --show-labels

# Config diagnostics
kubectl get configmap <cm> -n <ns> -o yaml
kubectl get secret <secret> -n <ns> -o yaml
kubectl exec <pod> -n <ns> -- env | sort

# Deployment diagnostics
kubectl rollout status deployment/<deploy> -n <ns>
kubectl rollout history deployment/<deploy> -n <ns>
kubectl get rs -n <ns>

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
