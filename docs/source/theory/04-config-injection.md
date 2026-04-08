# How ConfigMaps, Secrets, and Env Injection Work

Applications need configuration — database hostnames, credentials, feature flags. In Kubernetes, this configuration lives outside the container image and is injected at pod creation time.

## ConfigMaps and Secrets

Both are Kubernetes objects that store key-value pairs. The difference:

- **ConfigMap**: stores plain text. For non-sensitive config (hostnames, ports, database names).
- **Secret**: stores base64-encoded data. For sensitive values (passwords, API keys, tokens). Not encrypted by default — base64 is encoding, not encryption.

Both are namespaced — they must exist in the same namespace as the pod that references them.

## How values get into the container

### envFrom — inject all keys as env vars

```yaml
envFrom:
  - configMapRef:
      name: app-config
  - secretRef:
      name: app-secret
```

Every key in the ConfigMap/Secret becomes an environment variable in the container. If the ConfigMap has `POSTGRES_HOST: postgres`, the container sees `POSTGRES_HOST=postgres` in its environment.

### env with valueFrom — inject specific keys

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secret
        key: POSTGRES_PASSWORD
```

Maps a specific key from a specific object to a specific env var name. The env var name in the container can differ from the key name in the object.

### Volume mounts — inject as files

```yaml
volumes:
  - name: config-volume
    configMap:
      name: app-config
volumeMounts:
  - name: config-volume
    mountPath: /etc/config
```

Each key becomes a file in the mount path. Less common for simple env var config, more common for config files (nginx.conf, app settings files).

## What breaks

| Failure | What you see | How to diagnose |
|---|---|---|
| ConfigMap/Secret doesn't exist | `CreateContainerConfigError` — pod won't start | `kubectl describe pod` Events name the missing object |
| Wrong reference name (typo) | Same as above | Compare `envFrom` ref name against `kubectl get configmap` / `kubectl get secret` |
| Key doesn't exist in the object | Container starts but env var is empty or missing | `kubectl exec <pod> -- env` to check; compare against object keys |
| Value is wrong | App crashes or misbehaves at runtime | Compare runtime env (`kubectl exec -- env`) against what the app expects and what actually exists in the cluster (service names, DB names, etc.) |
| Secret double-encoded | Value looks like base64 gibberish inside the container | `kubectl get secret <s> -o jsonpath='{.data.<key>}' \| base64 -d` — if it still looks like base64, it was double-encoded |

## The timing rule

ConfigMap and Secret values are read when the pod is created. If you edit a ConfigMap or Secret, existing pods still have the old values. You must restart the pods to pick up changes:

```bash
kubectl rollout restart deploy/<deploy> -n <ns>
```

This is one of the most common interview gotchas — fixing a ConfigMap value without restarting pods means the fix hasn't actually taken effect.

## What to check during debugging

1. Does the ConfigMap/Secret the pod references actually exist? (`kubectl get configmap -n <ns>`)
2. Does the reference name match exactly? (character-for-character comparison)
3. Do the keys inside the object match what the app reads? (compare against app code)
4. Are the values correct? (compare against actual service names, decode secrets)
5. Were pods restarted after any changes?
