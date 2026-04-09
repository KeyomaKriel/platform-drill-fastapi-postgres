# Default Codespace Drill Setup

Use a pre-configured Codespace with k3d for the environment. Claude Code runs locally and generates a fresh unfamiliar app for each drill, then copies it to the Codespace.

---

## One-time setup

### 1. Fork the environment repo

```bash
gh repo fork cse-labs/kubernetes-in-codespaces --clone=false
```

This repo has a `.devcontainer/` that gives you a Codespace with k3d, kubectl, helm, and Docker — all pre-configured and ready to go.

### 2. Launch the Codespace

1. Go to your fork: `https://github.com/<your-username>/kubernetes-in-codespaces`
2. Click **Code** > **Codespaces** > **Create codespace on main**
3. Wait for the build (~3-5 min first time)
4. You now have a terminal with a running k3d cluster

### 3. Verify the environment

In the Codespace terminal:

```bash
kubectl get nodes
kubectl get pods -A
```

If the cluster isn't running:

```bash
k3d cluster create drill-cluster \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer"
```

---

## Each drill session

All steps below run in your **local terminal** (Claude Code), not the Codespace.

### 4. Ask Claude to generate an unfamiliar app

Open Claude Code locally:

```bash
claude
```

Then use one of these prompts. Claude generates the app locally, then you copy it to the Codespace and deploy it there.

**Generate + orientation drill:**

> Generate a fresh Python + Postgres web app for me to practice cold orientation on. Requirements:
> - Python framework (vary between FastAPI, Flask, or Django across drills)
> - Postgres database with at least one table seeded with data
> - 3-4 REST endpoints
> - Dockerfile
> - Raw K8s manifests: Deployment, Service, ConfigMap, Secret, PVC for Postgres, Ingress (nginx)
> - Use realistic but unfamiliar variable names, port numbers, namespace name, and resource names — nothing I've seen before
> - Put everything in ./codespace/drill-app/
> - Do NOT deploy it. Just generate the files.
> - Tell me when it's ready to copy.

**Generate + debugging drill:**

> Generate a fresh Python + Postgres web app for debugging practice. Requirements:
> - Python framework (vary between FastAPI, Flask, or Django across drills)
> - Postgres database with at least one table seeded with data
> - 3-4 REST endpoints
> - Dockerfile
> - Raw K8s manifests: Deployment, Service, ConfigMap, Secret, PVC for Postgres, Ingress (nginx)
> - Use realistic but unfamiliar variable names, port numbers, namespace name, and resource names — nothing I've seen before
> - Put everything in ./codespace/drill-app/
> - Include a file called BREAK.sh with a single kubectl command that injects ONE fault into the running deployment (e.g. wrong env var, bad image tag, broken probe). Do NOT tell me what the fault is.
> - Do NOT deploy it. Just generate the files.
> - Tell me when it's ready to copy.

**Generate + implementation drill:**

> Generate a fresh Python + Postgres web app for implementation practice. Requirements:
> - Python framework (vary between FastAPI, Flask, or Django across drills)
> - Postgres database with at least one table seeded with data
> - 3-4 REST endpoints
> - Dockerfile
> - Raw K8s manifests: Deployment, Service, ConfigMap, Secret, PVC for Postgres, Ingress (nginx)
> - Use realistic but unfamiliar variable names, port numbers, namespace name, and resource names — nothing I've seen before
> - Put everything in ./codespace/drill-app/
> - Include a file called TASK.md with a small, realistic Platform Engineer task — manifest/config level, completable in 15 minutes. Do NOT include the solution.
> - Do NOT deploy it. Just generate the files.
> - Tell me when it's ready to copy.

### 5. Copy the app to the Codespace

```bash
gh cs cp -e ./codespace/drill-app/ remote:~/drill-app/ -c <codespace-name>
```

To find your codespace name:

```bash
gh cs list
```

### 6. In the Codespace: deploy and drill

Switch to the Codespace terminal. Start your session log:

```bash
cd ~/drill-app
script -q -a ./session.log
```

Now orient yourself and deploy — this is the practice:

```bash
ls
cat README.md
# Find the manifests, Dockerfile, app code
# Figure out the build and deploy path yourself
# Build the image, load into k3d, create namespace, apply manifests
# Verify end-to-end with curl
```

For **debugging drills**: deploy first, verify it's healthy, then run `bash BREAK.sh` and close/clear your terminal so you don't see what it did. Then start a fresh session log and debug the symptom.

For **implementation drills**: deploy first, verify it's healthy, then read `TASK.md` and do the task.

### 7. Clean up between drills

In the Codespace:

```bash
rm -rf ~/drill-app
kubectl delete namespace <whatever-namespace-was-used>
```

Locally:

```bash
rm -rf ./codespace/drill-app
```

---

## Why this approach

- **Unfamiliar every time** — different app names, variable names, ports, endpoints, namespace, manifest structure each drill
- **No Claude Code needed in the Codespace** — Claude runs locally, generates files, you copy them over
- **Zero environment setup** — k3d, kubectl, Docker all pre-configured in the Codespace
- **Matches the interview format** — you're in a Codespace with an unfamiliar repo, deploying and debugging
- **Realistic K8s stack** — Python + Postgres + raw manifests

---

## Codespace tips

### Port forwarding
Codespaces auto-forward ports. Check the **Ports** tab in VS Code if `curl localhost` doesn't reach the app. You may need the forwarded URL instead.

### Timeout
Free-tier Codespaces stop after 30 min of inactivity. Bump this in GitHub settings (Settings > Codespaces > Default idle timeout) or keep a terminal active.

### Fresh vs persistent
Codespace state persists between stops/starts. For a truly clean environment, delete and recreate the Codespace. For a quick reset between drills, just delete the app directory and namespace.

### Costs
GitHub gives 120 core-hours/month free for Codespaces. A 4-core Codespace burns 4 hours per hour of use. That's ~30 hours of drill time per month on the free tier.
