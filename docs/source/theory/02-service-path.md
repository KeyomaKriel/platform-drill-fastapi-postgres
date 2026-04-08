# Service Path: App Process to External Client

Traffic follows a chain of objects from the outside world to the app process inside a container. Each link in the chain can be tested independently, which is why the reachability path (pod → service → ingress) works as a debugging method.

## The chain

```
Client (curl localhost/)
  │
  ▼
Ingress Controller (nginx pod in ingress-nginx namespace)
  │  reads Ingress resource rules: host, path, backend service+port
  ▼
Service (ClusterIP, in app namespace)
  │  uses selector to find matching Ready pods
  │  maintains Endpoints list of pod IPs
  │  forwards from service port to targetPort
  ▼
Pod (in app namespace)
  │  container listening on containerPort
  ▼
App Process (e.g. Uvicorn on port 8000)
```

## What each link does

### App process

The app binds to a port inside the container (e.g. `0.0.0.0:8000`). This is set in the `CMD`/`ENTRYPOINT` or app config. If the app doesn't bind, nothing else matters — there's nothing to connect to.

### Pod / containerPort

The pod exposes the container's port. `containerPort` in the manifest is documentation only — it doesn't actually open or close anything. What matters is that the app is actually listening on that port.

You test this layer with: `kubectl port-forward pod/<pod> 8080:<containerPort>` then `curl localhost:8080/`

### Service

A Service provides a stable internal address for a set of pods. It works through two mechanisms:

- **Selector**: label query that identifies which pods belong to this service. Must match the pod labels exactly.
- **Endpoints**: the list of `IP:port` pairs for pods that match the selector AND are Ready. Kubernetes maintains this automatically.

The Service maps its own `port` to the pod's `targetPort`. These can be different numbers (e.g. Service port 80 → targetPort 8000).

You test this layer with: `kubectl get endpoints <svc>` (are there IPs?), then `kubectl port-forward svc/<svc> 8080:<svc-port>` then `curl localhost:8080/`

### Ingress

An Ingress resource defines rules for routing external HTTP traffic to Services. The Ingress itself is just a config object — the actual routing is done by an Ingress Controller (e.g. nginx).

Key fields:
- `ingressClassName`: which controller handles this Ingress
- `host`: optional — if set, only requests with a matching `Host` header are routed (a plain `curl localhost/` may not match)
- `path` + `pathType`: which URL paths to match
- `backend.service.name` + `backend.service.port.number`: which Service to forward to — this must match the Service's `port`, not its `targetPort`

You test this layer with: `curl -i localhost/` or `curl -i -H "Host: <host>" localhost/` if a host rule is set.

## Port alignment

The most common routing bugs are port mismatches. Here's what must align:

```
App listens on          →  8000
Dockerfile EXPOSE       →  8000  (documentation, but should match)
Deployment containerPort→  8000  (documentation, but should match)
Probes target port      →  8000  (must match or probes fail)
Service targetPort      →  8000  (must match app's listening port)
Service port            →  80    (can be anything — this is what other things reference)
Ingress backend port    →  80    (must match Service port, not targetPort)
```

## Why testing layer by layer works

If the pod responds but the service doesn't, the problem is in the Service layer (selector, ports, endpoints). If the service responds but the external URL doesn't, the problem is in the Ingress layer. You don't need to guess — each layer is independently testable.
