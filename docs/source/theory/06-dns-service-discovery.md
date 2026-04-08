# What DNS and Service Discovery Mean In-Cluster

Inside a Kubernetes cluster, pods find each other by name, not by IP address. This is service discovery, and it runs on the cluster's internal DNS system.

## How it works

When you create a Service named `postgres` in namespace `drill`, Kubernetes DNS automatically creates a DNS record for it. Any pod in the cluster can resolve that name to the Service's ClusterIP.

### DNS name formats

| Format | Example | When to use |
|---|---|---|
| `<service>` | `postgres` | Works when caller is in the same namespace |
| `<service>.<namespace>` | `postgres.drill` | Works from any namespace |
| `<service>.<namespace>.svc.cluster.local` | `postgres.drill.svc.cluster.local` | The fully qualified domain name (FQDN) — always works |

Most apps use the short form (`postgres`) because they run in the same namespace as the service they're calling. If you need cross-namespace communication, use the full `<service>.<namespace>` form.

## How DNS resolution happens

1. App inside the container calls `getaddrinfo("postgres")` (any standard hostname lookup)
2. The container's `/etc/resolv.conf` points to the cluster DNS service (CoreDNS, usually at `10.96.0.10`)
3. CoreDNS resolves `postgres` → tries `postgres.drill.svc.cluster.local` (using the search domains from resolv.conf)
4. Returns the ClusterIP of the Service (e.g. `10.96.45.12`)
5. App connects to that IP; kube-proxy forwards to an actual pod IP from the endpoints

## What breaks

### Wrong hostname

The app uses a hostname that doesn't match any Service name. Example: app is configured with `POSTGRES_HOST=database` but the Service is named `postgres`.

**Log signal:** `Name or service not known` or `no such host`

**Diagnostic:** Compare the hostname from the app's env vars against `kubectl get svc -n <ns>`.

This is technically a Config/Env problem (the value is wrong), but it manifests as a DNS error.

### Wrong namespace

The app is in one namespace, the Service it's trying to reach is in another, and the short name doesn't resolve.

**Fix:** Use the qualified name `<service>.<namespace>` in the config.

### DNS itself is broken

If no hostnames resolve at all — not even `kubernetes.default`:

```bash
kubectl exec <pod> -n <ns> -- nslookup kubernetes.default
```

If this fails, DNS is broken cluster-wide. Common causes:
- CoreDNS pods in `kube-system` are not Running
- A NetworkPolicy is blocking egress to UDP port 53 in the `kube-system` namespace

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get networkpolicy -n <ns>
```

### Stale DNS / connection after service recreation

If a Service was deleted and recreated, the ClusterIP may have changed. Pods with cached connections may still try the old IP. A `rollout restart` fixes this.

## The key mental model

DNS is the glue between "the app says `connect to postgres`" and "traffic actually reaches the postgres pod." When a connection fails with a hostname error, there are only three possibilities: the hostname is wrong (config problem), the Service doesn't exist (missing or wrong namespace), or DNS itself is broken (CoreDNS or NetworkPolicy).
