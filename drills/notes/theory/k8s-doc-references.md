Here's the theory you should have in your head. Not deep expertise — just enough that when you see something in the interview, you understand *why* it's behaving that way, not just *what* to type.

**1. How a Pod gets scheduled (the lifecycle from creation to Running)**
Why: When a pod is Pending or stuck, you need to understand the chain — API server → scheduler → kubelet → container runtime. Knowing this tells you *where* in the chain the failure is.
Link: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/

**2. Container restart policies and exit codes**
Why: CrashLoopBackOff is one of the most common interview scenarios. You need to know what exit code 137 (OOMKill) vs 1 (app error) vs 0 (clean exit) means, and how `restartPolicy` affects behavior.
Link: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy

**3. How Services route traffic (selectors, endpoints, kube-proxy)**
Why: "App is unreachable" is the single most common interview problem. You need to understand that a Service selects pods by label, populates an Endpoints object, and kube-proxy handles the actual routing. If any link in that chain breaks, traffic fails.
Link: https://kubernetes.io/docs/concepts/services-networking/service/

**4. DNS resolution inside a cluster**
Why: When one service can't reach another by name, you need to know that Kubernetes DNS resolves `<service>.<namespace>.svc.cluster.local` and that pods in the same namespace can use just `<service>`. If DNS is broken (e.g., CoreDNS is down or a NetworkPolicy blocks UDP 53), everything breaks.
Link: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

**5. How readiness and liveness probes work (and how they differ)**
Why: Confusing these two is a common source of bugs. Readiness controls whether a pod gets traffic. Liveness controls whether a pod gets killed. A wrong liveness probe kills healthy containers. A wrong readiness probe starves them of traffic.
Link: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/

**6. How Deployments and ReplicaSets manage rollouts**
Why: When a rollout is stuck, you need to understand that a Deployment creates a new ReplicaSet, scales it up, and scales the old one down. If the new pods can't start, the rollout hangs. `kubectl rollout undo` rolls back to the previous ReplicaSet.
Link: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

**7. Resource requests vs limits**
Why: Requests determine scheduling (can this pod fit on a node?). Limits determine runtime enforcement (the pod gets OOMKilled if it exceeds memory limit). Mixing these up leads to either Pending pods or OOMKilled pods.
Link: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

**8. ConfigMaps and Secrets — how they're injected into pods**
Why: You need to know the difference between `envFrom` (loads all keys as env vars), `env.valueFrom.configMapKeyRef` (loads one key), and volume mounts (mounts as files). Each has different failure modes when the ConfigMap/Secret is missing or a key doesn't exist.
Link: https://kubernetes.io/docs/concepts/configuration/configmap/

**9. How NetworkPolicies work (default allow, deny, and the additive model)**
Why: By default, all traffic is allowed. A NetworkPolicy is a whitelist — once any policy selects a pod, all non-matching traffic is denied. This is unintuitive and easy to get wrong. You need to understand that ingress and egress are evaluated independently.
Link: https://kubernetes.io/docs/concepts/services-networking/network-policies/

**10. PersistentVolumes, PersistentVolumeClaims, and StorageClasses**
Why: When a PVC is Pending, you need to understand the binding model — a PVC requests storage, a StorageClass provisions it dynamically (or a PV is matched statically). Access modes (ReadWriteOnce vs ReadWriteMany) and capacity must match.
Link: https://kubernetes.io/docs/concepts/storage/persistent-volumes/

**11. Init containers**
Why: Init containers run before the main container and must complete successfully. If they fail, the main container never starts. The pod shows `Init:0/1` instead of the usual statuses. The diagnostic path is different — you must specify `-c <init-container-name>` to get logs.
Link: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/

**12. RBAC — Roles, RoleBindings, ServiceAccounts**
Why: If the app needs to talk to the Kubernetes API (or if the interview tests it), you need to understand that a ServiceAccount is assigned to a pod, a Role defines permissions, and a RoleBinding connects them. The `roleRef` in a RoleBinding is immutable — you can't edit it, only delete and recreate.
Link: https://kubernetes.io/docs/reference/access-authn-authz/rbac/

**13. Ingress and IngressClasses**
Why: Ingress is the layer between external traffic and your Services. You need to know that an Ingress resource is just a config object — it does nothing without an Ingress controller (like nginx). The `ingressClassName` field connects the two. Path rules and backend service references are common failure points.
Link: https://kubernetes.io/docs/concepts/services-networking/ingress/

**14. Container image naming and pull policies**
Why: `imagePullPolicy: Always` vs `IfNotPresent` vs `Never` changes behavior significantly, especially in local clusters like kind. You need to know that `:latest` defaults to `Always`, and a specific tag defaults to `IfNotPresent`. In the interview environment, this could be the difference between a pull error and a successful deploy.
Link: https://kubernetes.io/docs/concepts/containers/images/

**15. kubectl explain**
Why: If you forget a field name or structure during the interview, `kubectl explain deployment.spec.template.spec.containers.livenessProbe` gives you the schema right in the terminal. Faster than searching docs. Knowing this exists is a multiplier.
Link: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_explain/

Every link is official Kubernetes docs. They're the most accurate and the most likely to match what you'll see in the interview. Skip the blog posts and tutorials — these 15 pages are all you need to read.