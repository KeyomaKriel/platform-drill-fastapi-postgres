# Drill Setup: fif911/kubernetes-front-end-backend-example

FastAPI + Postgres + raw K8s manifests. Unfamiliar repo for Codespace interview practice.

---

## Why this repo

- FastAPI + PostgreSQL — matches your target stack
- Raw K8s manifests with ConfigMaps, Secrets, RBAC, Ingress
- Richer than your source-repo (has frontend, multiple manifest directories, RBAC roles)
- You haven't seen it before — orientation is genuinely tested

**Ignore:** The React frontend, Helm charts, and GCP-specific configs. Focus on backend + Postgres + K8s manifests.

---

## One-time setup (run from your local machine)

These steps fork the repo, add Codespace support, and push. After this, you launch Codespaces from the GitHub UI.

### 1. Fork and clone the repo

```bash
cd ~/code  # or wherever you keep repos
gh repo fork fif911/kubernetes-front-end-backend-example --clone
cd kubernetes-front-end-backend-example
```

### 2. Add devcontainer config

```bash
mkdir -p .devcontainer
```

Create `.devcontainer/devcontainer.json`:

```json
{
  "name": "K8s Drill Environment",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/kubectl-helm-minikube:1": {
      "kubectl": "latest",
      "helm": "latest",
      "minikube": "none"
    },
    "ghcr.io/devcontainers/features/node:1": {}
  },
  "postCreateCommand": ".devcontainer/setup.sh",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-kubernetes-tools.vscode-kubernetes-tools",
        "redhat.vscode-yaml"
      ]
    }
  },
  "remoteUser": "vscode"
}
```

Create `.devcontainer/setup.sh`:

```bash
#!/bin/bash
set -e

# Install k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install Claude Code
npm install -g @anthropic-ai/claude-code

echo ""
echo "=== Environment ready ==="
echo "Tools available: docker, kubectl, helm, k3d, claude"
```

Push it:

```bash
chmod +x .devcontainer/setup.sh
git add .devcontainer/
git commit -m "Add devcontainer for Codespace drills"
git push
```

---

## Each drill session

### 3. Launch the Codespace

1. Go to your fork on GitHub: `https://github.com/KeyomaKriel/kubernetes-front-end-backend-example`
2. Click **Code** > **Codespaces** > **Create codespace on main**
3. Wait for build (first time: ~3-5 min, subsequent: ~30s)

### 4. Create the k3d cluster

In the Codespace terminal:

```bash
k3d cluster create drill-cluster \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0"
```

This creates a cluster in ~15 seconds with a load balancer mapping ports 80/443. Traefik is disabled so you can install nginx-ingress if the repo's manifests use it, or re-enable it if they expect Traefik.

Install nginx ingress controller (if the repo uses Ingress resources with `ingressClassName: nginx`):

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

> **Note:** If the repo's Ingress manifests don't specify an ingressClassName, or use Traefik, skip the nginx install and recreate the cluster without `--disable=traefik`.

### 5. Orient and deploy (this IS the practice)

**Do NOT read ahead. This is where you practice cold orientation.**

Start your timer (60 minutes). Open a second terminal tab for your debug work:

```bash
script -q -a ./session.log
```

Now orient yourself:

```bash
# What's in this repo?
ls
cat README.md

# Find the manifests
find . -name "*.yaml" -o -name "*.yml" | head -30

# Find the Dockerfile(s)
find . -name "Dockerfile*"

# Read the app code — what does it do? What endpoints? What env vars?
# Find the K8s manifests — what resources? What namespace? What connections?
# Figure out the build and deploy path yourself.
```

Your goal: get the backend + Postgres running in the k3d cluster and verify end-to-end. You will need to:

1. Read the app code to understand endpoints and DB connection
2. Read the K8s manifests to understand the deploy topology
3. Build the Docker image and import it into k3d: `k3d image import <image>:<tag> -c drill-cluster`
4. Create a namespace and apply manifests
5. Debug anything that doesn't work (image names, ports, env vars may need adjusting for k3d vs the original target environment)
6. Verify with curl

**Expect things to not work first try.** The manifests may target MicroK8s or GCP — adapting them to k3d is realistic interview work.

### 6. Launch Claude Code as interviewer

In the first terminal tab:

```bash
claude
```

**For orientation drill:**
> Act as a Platform Engineer interviewer. I've just opened this repo for the first time. Ask me to walk through what the application does, how it's deployed, and how I'd verify it's working. Stay silent while I work. When I say "evaluate", read ./session.log and give me structured feedback.

**For debugging drill:**
> Act as a Platform Engineer interviewer. I've deployed this app to a k3d cluster. Break one thing in the cluster using base64-encoded kubectl commands so I can't see what you did. Give me a vague symptom prompt. Stay silent while I debug. When I say "evaluate", read ./session.log and give me structured feedback.

**For implementation drill:**
> Act as a Platform Engineer interviewer. Give me a small, realistic Platform Engineer task to do on this repo's K8s deployment — something completable in 15 minutes. Manifest/config level, not app code. Stay silent while I work. When I say "evaluate", read ./session.log and give me structured feedback.

### 7. Clean up after drill

```bash
# Delete the Codespace when done (from GitHub UI or):
gh codespace delete
```

Or keep it running for another round — just delete and recreate the k3d cluster:

```bash
k3d cluster delete drill-cluster
# Then repeat from step 4
```

---

## Codespace-specific gotchas

### Port forwarding
Codespaces auto-forwards ports. If `curl localhost` doesn't hit the ingress, check the **Ports** tab in VS Code. You may need to use the forwarded URL instead, or set the port visibility to public.

### Docker-in-Docker performance
Building images inside a Codespace is slower than local. Budget an extra minute for builds.

### Codespace timeout
Free-tier Codespaces stop after 30 min of inactivity. Keep a terminal active or bump the timeout in GitHub settings (Settings > Codespaces > Default idle timeout).

### Persistent storage
Codespace state persists between stops/starts (unlike a fresh Codespace). If you want a truly fresh environment for each drill, delete and recreate the Codespace.

---

## Drill rotation plan

To keep things unfamiliar, vary what you practice each session:

| Session | Focus | What to do |
|---------|-------|------------|
| 1 | Cold orientation | Deploy from scratch. Don't look at the repo beforehand. |
| 2 | Debugging | Get it healthy, then have Claude break it. |
| 3 | Implementation | Have Claude give you a manifest-level task. |
| 4 | Debugging (different domain) | Another break/fix, different failure domain. |
| 5 | Verification/trade-off | Have Claude ask you to evaluate something about the deployment. |

After exhausting this repo, move to **waprin/kubernetes_django_postgres_redis** (Django + Postgres + Redis) for a different framework with the same setup process.
