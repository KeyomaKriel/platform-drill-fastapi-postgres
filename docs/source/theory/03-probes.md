# What Probes Do and How They Fail

Probes are Kubernetes' way of checking whether a container is alive, ready, and started. They directly control whether a pod receives traffic and whether it gets restarted.

## The three probe types

### Readiness probe

**Question it answers:** "Can this container handle requests right now?"

- If it fails, the pod is removed from Service endpoints — it stops receiving traffic.
- If it passes again, the pod is added back.
- It does NOT restart the container.
- A pod that fails readiness shows `Running` but `0/1` Ready.

### Liveness probe

**Question it answers:** "Is this container still alive?"

- If it fails (past the failure threshold), Kubernetes kills and restarts the container.
- A pod that is repeatedly killed by liveness shows `Running` + `1/1` but RESTARTS climbing.
- Exit code 143 (SIGTERM) in the previous container state is a sign of liveness killing.

### Startup probe

**Question it answers:** "Has this container finished starting up?"

- While the startup probe is running, liveness and readiness probes are disabled.
- Gives slow-starting apps time to initialise without being killed by liveness.
- If the startup probe never passes, the container is eventually killed.

## How a probe is configured

```yaml
readinessProbe:
  httpGet:
    path: /health        # the URL path to hit
    port: 8000           # the port to hit
  initialDelaySeconds: 5 # wait this long before first check
  periodSeconds: 10      # check every N seconds
  timeoutSeconds: 1      # each check must respond within N seconds
  failureThreshold: 3    # fail this many times before taking action
  successThreshold: 1    # pass this many times before marking healthy
```

Probe types: `httpGet` (checks HTTP status — 200-399 = pass), `tcpSocket` (checks port is open), `exec` (runs a command — exit 0 = pass).

## How probes fail

| Symptom | What's happening | Likely cause |
|---|---|---|
| Pod `Running` but `0/1` Ready | Readiness probe failing | Wrong path, wrong port, or app genuinely unhealthy |
| Pod `Running` + `1/1` but restarts climbing | Liveness probe killing container | Wrong path/port, timing too aggressive, or app becomes unhealthy |
| Pod never reaches `Running` (killed during startup) | Startup probe never passes | initialDelaySeconds too short, or app genuinely can't start |
| `describe pod` shows `Unhealthy` events | Probe is running and failing | Read the event detail — it names the path, port, and HTTP status |

## Debugging approach

1. `kubectl describe pod <pod>` — look at Events for `Unhealthy` messages. They show which probe, which path/port, and what the response was.
2. `kubectl get pod <pod> -o jsonpath='{.spec.containers[0].readinessProbe}'` — see the exact probe config.
3. `kubectl port-forward pod/<pod> 8080:<container-port>` then manually curl the probe path — does it return 200?
4. Compare the configured probe path/port against what the app actually serves (from repo-first orientation).

## The key mental model

Probes are a contract between the app and Kubernetes. The app promises "I will return 200 on this path/port when I'm healthy." The manifest configures Kubernetes to check that promise. When the contract is broken — wrong path, wrong port, timing that doesn't match app startup time — the pod either never receives traffic (readiness) or keeps getting killed (liveness).
