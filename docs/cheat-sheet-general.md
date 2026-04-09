# Interview Cheat Sheet

## Fix a live cluster (no manifest to edit)

### Env var — fastest

```bash
kubectl set env deployment/<name> -n <ns> KEY=value
```

Pods restart automatically.

### Edit a resource with nano

```bash
EDITOR=nano kubectl edit deployment/<name> -n <ns>
```

In nano:
- `Ctrl+W` — search (type text, Enter)
- Arrow keys — navigate
- Backspace/type — edit
- `Ctrl+O` then Enter — save
- `Ctrl+X` — exit

Pods restart automatically after save.

### Patch a resource (no editor needed)

```bash
# Change a single field
kubectl patch deployment/<name> -n <ns> --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"myapp:v2"}]'

# Remove a field
kubectl patch deployment/<name> -n <ns> --type='json' \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/env/0"}]'
```

Pods restart automatically.

### When to use which

| Situation | Use |
|-----------|-----|
| Fix an env var | `kubectl set env` |
| Fix an image tag | `kubectl set image` |
| Fix a probe, port, label, or anything else | `kubectl edit` with nano |
| Script a precise change | `kubectl patch` |
| Manifest is wrong and you have the file | Edit the file in VS Code, `kubectl apply -f` |

---

## Fix via manifest (bug is in the repo)

```bash
# Edit in VS Code (what you know)
code manifests/tracker-deployment.yaml

# Apply
kubectl apply -f manifests/tracker-deployment.yaml -n <ns>

# If apply says "unchanged" but cluster is wrong, force recreate:
kubectl rollout restart deployment/<name> -n <ns>
```

---

## Triage commands

```bash
# Overview
kubectl get all -n <ns>
kubectl get pods -n <ns>
kubectl get endpoints -n <ns>

# Dig into a pod
kubectl describe pod <name> -n <ns>
kubectl logs <name> -n <ns>
kubectl logs <name> -n <ns> --previous    # crashed container

# Check config
kubectl get configmap <name> -n <ns> -o yaml
kubectl get secret <name> -n <ns> -o yaml
kubectl get deployment <name> -n <ns> -o yaml

# Test connectivity
kubectl port-forward svc/<name> -n <ns> 8080:80 &
curl localhost:8080/
kubectl exec -it <pod> -n <ns> -- sh

# End-to-end
curl localhost/
curl localhost/health
curl localhost/items
```

---

## Nano survival

```
Ctrl+W     search
Ctrl+O     save (then Enter to confirm)
Ctrl+X     exit
Ctrl+K     cut line
Ctrl+U     paste line
Arrow keys navigate
```

Set as default for kubectl:

```bash
export EDITOR=nano
```

---

## Vim survival (if nano is not available)

```
i          enter insert mode (now you can type)
Esc        exit insert mode
:wq Enter  save and quit
:q! Enter  quit without saving
/text      search for "text"
dd         delete a line
u          undo
```

---

## Repo orientation

```bash
ls
tree -L 2
cat README.md
cat Dockerfile
find . -name "*.yaml" -path "*/k8s/*" -o -name "*.yaml" -path "*/manifests/*"
```

---

## Search

```bash
# Find a file
find . -name "*.yaml"
find . -iname "*service*"

# Search file contents
grep -r "PGHOST" .
grep -r "containerPort" manifests/
rg "kind:\s*Service"
```

---

## Docker + k3d

```bash
docker build -t <image>:local .
k3d image import <image>:local -c <cluster-name>
k3d cluster list
```

---

## Key precedence rules

- Inline `env` on a Deployment **overrides** `envFrom` (ConfigMap/Secret) for the same key
- `imagePullPolicy: Never` means Kubernetes won't pull from a registry — image must be loaded locally
- Readiness probe failure → pod removed from Service endpoints (no traffic)
- Liveness probe failure → pod restarted
