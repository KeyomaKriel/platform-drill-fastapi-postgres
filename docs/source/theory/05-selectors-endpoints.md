# How Selectors and Endpoints Work

Selectors and endpoints are the mechanism that connects a Service to the pods behind it. Understanding this link is critical because a broken selector is one of the most common causes of "pods are healthy but I can't reach the app."

## Labels and selectors

Every pod has labels — key-value pairs attached to its metadata:

```yaml
metadata:
  labels:
    app: platform-drill-api
    version: v1
```

A Service has a selector — a label query that picks which pods it targets:

```yaml
spec:
  selector:
    app: platform-drill-api
```

The selector must match the pod labels **exactly**. `app: api` does not match `app: platform-drill-api`. Even one character difference means zero matches.

## Endpoints

Endpoints are the result of the selector match. Kubernetes automatically maintains an Endpoints object for each Service. It contains the list of `IP:port` pairs for all pods that:

1. Match the Service selector
2. Are in a `Ready` state (readiness probe passing)

Both conditions must be true. A pod that matches the selector but isn't Ready won't appear in endpoints.

```bash
kubectl get endpoints <svc> -n <ns>
```

**Healthy output:** `10.244.0.5:8000,10.244.0.6:8000` — pod IPs with ports.

**Broken output:** `<none>` — no pods match, or no matching pods are Ready.

## How traffic flows through the Service

1. Client sends request to `<service-name>:<port>` (e.g. `platform-drill-api:80`)
2. kube-proxy (or iptables rules) picks a pod IP from the endpoints list
3. Request is forwarded to `<pod-ip>:<targetPort>` (e.g. `10.244.0.5:8000`)

The Service `port` is what callers use. The `targetPort` is what the pod actually listens on. These can be different numbers.

## What breaks

| Symptom | Cause | How to check |
|---|---|---|
| Endpoints empty, pods Running + Ready | Selector mismatch | Compare `kubectl describe svc` Selector against `kubectl get pods --show-labels` |
| Endpoints empty, pods Running but `0/1` | Readiness probe failing | Pods match but aren't Ready — fix readiness first |
| Endpoints populated but wrong port | targetPort mismatch | `kubectl describe svc` shows TargetPort; compare against container's listening port |
| Endpoints populated but traffic fails | Port in endpoints doesn't match app's actual listening port | Check containerPort vs app's actual bind port |

## The debugging shortcut

`kubectl get endpoints <svc>` is the single fastest check for service routing problems. If it shows IPs, the selector is working and pods are Ready. If it shows `<none>`, either the selector doesn't match or no pods are Ready — and that distinction tells you exactly where to look next.
