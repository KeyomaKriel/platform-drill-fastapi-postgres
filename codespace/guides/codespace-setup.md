# Codespace Interview Practice — Setup Guide

Practice Platform Engineer interview drills in GitHub Codespaces using unfamiliar repos, matching the real interview environment.

---

## Recommended Repos

### Primary picks (app + K8s manifests, good for 60-min drills)

| Repo | Stack | Why it's useful |
|------|-------|-----------------|
| [fif911/kubernetes-front-end-backend-example](https://github.com/fif911/kubernetes-front-end-backend-example) | FastAPI + Postgres + React, Helm, RBAC, Ingress | Closest to your drill format but richer — frontend, Helm charts, RBAC roles. Forces genuine orientation. |
| [mkjelland/spring-boot-postgres-on-k8s-sample](https://github.com/mkjelland/spring-boot-postgres-on-k8s-sample) | Spring Boot + Postgres | Different language (Java). Simple two-tier app. Tests orientation when the code is unfamiliar. |
| [waprin/kubernetes_django_postgres_redis](https://github.com/waprin/kubernetes_django_postgres_redis) | Django + Postgres + Redis | Three-tier app. More services to reason about. Different deploy patterns. |
| [vladimirmukhin/kubernetes-interview-challenge](https://github.com/vladimirmukhin/kubernetes-interview-challenge) | Python HTTP server + K8s | Progressive 9-step challenge: run, Dockerize, deploy, add probes, ConfigMaps. |
| [4OH4/kubernetes-fastapi](https://github.com/4OH4/kubernetes-fastapi) | FastAPI (stateless) + HPA | Simpler (no DB), but has HPA and load testing. Good for implementation/verification tasks. |

### Break/fix scenario banks (steal fault ideas from these)

| Repo | Format |
|------|--------|
| [RX-M/bust-a-kube](https://github.com/RX-M/bust-a-kube) | Categorised broken manifests with solutions. Covers workload, networking, config, security. |
| [syseleven/kubernetes-debugging-workshop](https://github.com/syseleven/kubernetes-debugging-workshop) | 15 structured exercises with setup/cleanup scripts. |
| [mhausenblas/troubleshooting-k8s-apps](https://github.com/mhausenblas/troubleshooting-k8s-apps) | Numbered scenarios with broken and fixed YAML. |
| [iam-veeramalla/kubernetes-troubleshooting-zero-to-hero](https://github.com/iam-veeramalla/kubernetes-troubleshooting-zero-to-hero) | 5 core failure domains: ImagePullBackOff, CrashLoopBackOff, scheduling, storage, NetworkPolicy. |

### Devcontainer references (steal Codespace configs from these)

| Repo | Setup |
|------|-------|
| [cse-labs/kubernetes-in-codespaces](https://github.com/cse-labs/kubernetes-in-codespaces) | k3d in Codespaces, lifecycle scripts, production-grade pattern. |
| [chdalski/kubernetes-exercises](https://github.com/chdalski/kubernetes-exercises) | DevContainer with Docker-in-Docker for K8s exercises. |

---

## Step-by-Step Setup

### Step 1: Fork the repo

Pick a repo from the primary picks above. Fork it to your GitHub account.

```
# Example
gh repo fork fif911/kubernetes-front-end-backend-example --clone=false
```

### Step 2: Add a devcontainer config

Most of the repos above don't have Codespace support. Add one.

Create `.devcontainer/devcontainer.json` in your fork:

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

# Install kind
KIND_VERSION="v0.27.0"
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install Claude Code (requires Node, installed via feature above)
npm install -g @anthropic-ai/claude-code

echo ""
echo "=== Environment ready ==="
echo "Tools: docker, kubectl, helm, kind, claude"
echo ""
echo "Next: create a kind cluster and deploy the app."
```

Make the script executable and push:

```bash
chmod +x .devcontainer/setup.sh
git add .devcontainer/
git commit -m "Add devcontainer for Codespace drills"
git push
```

### Step 3: Launch the Codespace

1. Go to your fork on GitHub
2. Click **Code** > **Codespaces** > **Create codespace on main**
3. Wait for the container to build (first time takes 3-5 minutes)
4. You now have a browser-based VS Code with `docker`, `kubectl`, `helm`, and `kind` available

### Step 4: Create a kind cluster inside the Codespace

In the Codespace terminal:

```bash
# Create cluster with ingress support
cat <<'EOF' | kind create cluster --name drill-cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

# Install nginx ingress controller (kind-specific)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Step 5: Deploy the app from the repo

This varies per repo. The point is to **orient yourself** — read the README, find the manifests, figure out the deploy path. This is the practice.

Example for the FastAPI + Postgres repo:

```bash
# Read the repo first
ls
cat README.md

# Find and inspect manifests
find . -name "*.yaml" -path "*/k8s/*" -o -name "*.yaml" -path "*/kubernetes/*"

# Build and load the image
docker build -t app:local .
kind load docker-image app:local --name drill-cluster

# Apply manifests (adapt to what the repo actually has)
kubectl create namespace app
kubectl apply -f k8s/ -n app

# Verify
kubectl get all -n app
curl localhost/
```

### Step 6: Use Claude Code as interviewer

In the Codespace terminal:

```bash
claude
```

Then tell Claude:

> "I've deployed this app to a kind cluster. Act as a Platform Engineer interviewer. Break something in the cluster and give me a vague symptom prompt. Don't tell me what you broke. When I say 'evaluate', read my terminal history and give me structured feedback on my debugging process."

Or for orientation:

> "I've just opened this repo for the first time. Interview me: ask me to walk you through what this application does, how it's deployed, and how I'd verify it's working. Evaluate my process."

### Step 7: Debug in a separate terminal tab

Open a second terminal tab in the Codespace (Ctrl+Shift+`). This is your debug terminal.

```bash
# Start session log
script -q -a ./session.log

# Now triage...
kubectl get all -n app
kubectl describe pod <pod-name> -n app
# etc.
```

When done, go back to the Claude Code tab and say "evaluate my fix" or "evaluate".

---

## Tips for Realistic Practice

### Vary the repos
Don't drill the same repo twice in a row. Rotate through at least 3 different repos so orientation stays genuinely unfamiliar.

### Don't read the repo before launching
The interview tests cold orientation. Fork it, launch the Codespace, and start fresh — don't browse the repo on GitHub first.

### Use Codespace port forwarding
Codespaces auto-forward ports. If `curl localhost` doesn't work for ingress, check the **Ports** tab in VS Code and use the forwarded URL instead.

### Time yourself
Set a 60-minute timer. The time pressure changes how you triage.

### Practice narration
Talk out loud even when alone. The interview evaluates communication as much as technical skill. Say what you're checking and why before running each command.

---

## Alternative: No-Fork Quick Start

If you don't want to set up devcontainers, you can use the repos that already have Codespace support:

1. [cse-labs/kubernetes-in-codespaces](https://github.com/cse-labs/kubernetes-in-codespaces) — k3d cluster auto-created, apps pre-deployed
2. [chdalski/kubernetes-exercises](https://github.com/chdalski/kubernetes-exercises) — Docker-in-Docker devcontainer, K8s exercise focus

These won't perfectly match a tech-test repo, but they get you into a Codespace with K8s immediately — zero setup.

---

## Drill Workflow Summary

```
1. Fork unfamiliar repo
2. Add .devcontainer/ (if missing)
3. Launch Codespace
4. Create kind cluster + deploy app
5. Open Claude Code → ask it to interview you
6. Debug in separate terminal tab
7. Return to Claude Code → "evaluate"
8. Review feedback, repeat with different repo
```
