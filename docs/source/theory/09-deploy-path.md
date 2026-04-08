# Deploy Path Awareness: Build, Load, Apply, Restart, Verify

The deploy path answers: "How do I get a change from the repo into the running cluster?" Getting this wrong means your fix doesn't take effect — or worse, gets silently overwritten.

## Why this matters in an interview

When you find a bug and know the fix, you still need to execute the fix correctly. A code change requires rebuilding the image. A ConfigMap edit requires restarting pods. A manifest-only change requires `kubectl apply`. If you skip a step, the fix is dead on arrival and you've burned interview time.

## The two tracks

The deploy path has two tracks that merge at the Deployment manifest:

**Track 1: The image** — what runs inside the container.

```
App code + Dockerfile
       │
       ▼
  docker build -t <image>:<tag> .
       │
       ▼
  Image exists on your machine
       │
       ▼
  Get it into the cluster:
    • kind:     kind load docker-image <image>:<tag> --name <cluster>
    • minikube: minikube image load <image>:<tag>
    • registry: docker push <registry>/<image>:<tag>
```

**Track 2: The manifests** — how Kubernetes should run the image.

```
k8s/*.yaml (Deployment, Service, Ingress, ConfigMap, Secret, etc.)
       │
       ▼
  kubectl apply -f k8s/ -n <ns>
```

**Where they meet:** The Deployment manifest has an `image:` field that references the image by name and tag. When Kubernetes creates a pod, it looks for that image. If `imagePullPolicy: Never`, the image must already be on the node (Track 1). If `Always` or `IfNotPresent` with a registry tag, Kubernetes pulls it from the registry.

## The full sequence (for code changes)

```
1. Edit the code or Dockerfile
2. Rebuild the image          docker build -t <image>:<tag> .
3. Load into the cluster      kind load docker-image <image>:<tag> --name <cluster>
4. Apply updated manifests    kubectl apply -f k8s/     (if manifests changed)
5. Restart if needed          kubectl rollout restart deploy/<deploy> -n <ns>
6. Verify                     kubectl get pods, curl, etc.
```

Steps 3 and 5 are the ones most commonly forgotten.

Step 5 is needed when the image tag didn't change (e.g. still `:local`). Kubernetes doesn't know the image content is different — it thinks nothing changed. `rollout restart` forces new pods that pick up the fresh image from the node. If you changed the tag and updated the Deployment manifest, step 4 triggers an automatic rollout and step 5 is unnecessary.

## Which steps are needed for which change

| What changed | Steps needed |
|---|---|
| App code (Python, JS, etc.) | Rebuild image → load → rollout restart (or apply if image tag changed) → verify |
| Dockerfile | Rebuild image → load → rollout restart → verify |
| ConfigMap or Secret value | Edit the object → rollout restart → verify |
| Deployment manifest (probes, resources, env refs) | Apply manifest → verify (new pod template triggers automatic rollout) |
| Service manifest (selector, ports) | Apply manifest → verify (takes effect immediately, no restart needed) |
| Ingress manifest | Apply manifest → verify (takes effect immediately) |
| NetworkPolicy | Apply manifest → verify (takes effect immediately) |
| Runtime-only fix (quick patch) | `kubectl patch` / `kubectl set image` / `kubectl edit` → verify |

## Key details

### Image loading in kind/minikube

In a kind or minikube cluster, images are not pulled from a registry. They're loaded directly into the cluster's node:

```bash
kind load docker-image <image>:<tag> --name <cluster>
```

If `imagePullPolicy: Never` is set (common in kind setups), the image MUST be pre-loaded. If you rebuild but forget to load, the pod will use the old image (if the tag didn't change) or fail with `ErrImageNeverPull`.

### The rollout restart trap

Editing a ConfigMap or Secret does NOT automatically restart pods. The pods still have the old values in their environment. You must explicitly restart:

```bash
kubectl rollout restart deploy/<deploy> -n <ns>
```

This creates new pods that read the updated values. The old pods are terminated.

However, if you change the Deployment spec itself (image, env refs, probes, resources), applying the manifest triggers an automatic rollout — no `rollout restart` needed.

### `kubectl apply` vs `kubectl patch` vs `kubectl edit`

| Command | When to use |
|---|---|
| `kubectl apply -f <file>` | You have the manifest file and want to apply the full desired state |
| `kubectl edit <resource>` | Quick interactive edit of a live resource — good for one-off fixes |
| `kubectl patch <resource> -p '<json>'` | Targeted field change without opening an editor |
| `kubectl set image` | Change just the image on a deployment |

In an interview, `kubectl edit` and `kubectl patch` are fastest for one-off fixes. `kubectl apply -f` is correct when you're working from manifest files in the repo.

### How to identify the deploy path from an unfamiliar repo

Look for these clues during repo-first orientation:

1. **`Makefile` / `justfile` / `scripts/`** — often has `build`, `deploy`, `load` targets
2. **Manifest structure** — `k8s/*.yaml` = raw manifests; `Chart.yaml` = Helm; `kustomization.yaml` = Kustomize
3. **`imagePullPolicy`** — `Never` or `IfNotPresent` with a `:local` tag = images loaded directly
4. **CI config** — `.github/workflows/`, `Jenkinsfile` — shows the pipeline steps
5. **README** — may describe the steps, but verify against the actual files

## The mental model

Every fix has two parts: knowing *what* to change and knowing *how* to make that change take effect. The deploy path is the second part. Before you touch anything, know the path: do I need to rebuild? Do I need to load? Do I need to restart? Do I need to apply? Getting the sequence right is what separates "I found the bug" from "I fixed the bug."
