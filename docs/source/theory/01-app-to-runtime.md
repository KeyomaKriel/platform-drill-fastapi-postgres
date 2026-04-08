# How App Code, Env Vars, Dockerfile, Manifests, and Runtime Fit Together

There are four layers between source code and a running container in Kubernetes. Each layer depends on the one before it. When something breaks, the fault usually lives at a boundary between layers — a mismatch between what one layer provides and the next one expects.

## The four layers

### 1. App code

The application source. It defines:
- What endpoints exist and what they return
- What environment variables it reads (and what happens if they're missing)
- What external dependencies it needs (database, cache, external API)
- What happens at startup (connect to DB, run migrations, seed data)
- What port it listens on

The app doesn't know it's running in Kubernetes. It just reads env vars, listens on a port, and talks to dependencies via hostnames.

### 2. Dockerfile

The bridge between source code and a container image. It defines:
- The base image (language runtime, OS, available tools)
- How dependencies are installed
- What files are copied into the image
- The port the container exposes (`EXPOSE`)
- The startup command (`CMD` / `ENTRYPOINT`)

The Dockerfile produces an image. The image is immutable — once built, it doesn't change. If the app code changes, you rebuild the image.

### 3. Kubernetes manifests

The contract between the image and the cluster. Manifests define:
- **Deployment**: which image to run, how many replicas, env var injection, resource limits, probes, init containers, service account
- **ConfigMap / Secret**: the actual values that get injected as env vars
- **Service**: how other things inside the cluster find and reach the pods
- **Ingress**: how external traffic reaches the Service
- **NetworkPolicy**: what traffic is allowed between pods and namespaces

The manifests tell Kubernetes *how* to run the image and *how* to wire it into the network. They don't contain app logic — they contain operational config.

### 4. Runtime

What's actually running in the cluster right now. This is the live state: pods, containers, env vars injected, network routes active, probe results, actual resource usage.

Runtime can diverge from manifests if someone patched something directly, if a rollout is in progress, or if a config object was changed without restarting the pods.

## Where mismatches happen

Most debugging comes down to a mismatch between two adjacent layers:

| Boundary | Example mismatch |
|---|---|
| App ↔ Dockerfile | App listens on port 8000, Dockerfile `EXPOSE`s 3000 |
| App ↔ Manifests | App reads `POSTGRES_HOST`, ConfigMap provides `DB_HOST` |
| Dockerfile ↔ Manifests | Container exposes 8000, Service targetPort is 80 |
| Manifests ↔ Runtime | ConfigMap value was edited but pods weren't restarted |

## Why this matters for debugging

When you orient to the repo, you're building a mental model of what each layer promises. When you inspect the cluster, you're checking whether the runtime matches those promises. The gap between "what the repo says should be true" and "what's actually true in the cluster" is where the bug lives.
