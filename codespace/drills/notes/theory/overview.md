Here's the list split into essential vs nice-to-have, plus video recommendations.

---

**ESSENTIAL — Know this cold. These are the failure domains you'll actually debug.**

1. **How Services route traffic (selectors → endpoints → kube-proxy)** — Because "app is unreachable" is the most likely interview scenario and you need to trace the chain.
2. **Readiness vs liveness vs startup probes** — Because probe misconfiguration causes the most confusing symptoms (pod looks Running but nothing works, or healthy pods keep getting killed).
3. **The health check failure cascade (probe fails → not Ready → removed from endpoints → no traffic)** — Because being able to articulate this chain out loud is exactly what interviewers want to hear.
4. **ConfigMaps and Secrets injection (envFrom vs env vs volume mount, what happens when missing)** — Because bad config is one of the most common planted bugs and you need to know where to look.
5. **Container command vs args (how Docker ENTRYPOINT/CMD maps to K8s command/args)** — Because a `command:` that wipes out the entrypoint is a classic subtle break that's hard to spot if you don't know the override rules.
6. **Resource requests vs limits (requests = scheduling, limits = runtime enforcement, 137 = OOMKill)** — Because Pending pods and OOMKilled pods are common interview scenarios and you need to explain why.
7. **Kubernetes DNS (service-name.namespace.svc.cluster.local)** — Because cross-namespace or broken DNS resolution shows up when one service can't find another.
8. **Pod lifecycle and restart policies** — Because you need to read pod status and exit codes fluently. Exit code 137 vs 1 vs 0 each mean something different.
9. **Init containers (run before main container, must complete, different log path)** — Because `Init:0/1` requires a different diagnostic path and you already hit this during Phase 1 setup.
10. **NetworkPolicy model (default allow, additive deny, ingress vs egress independent)** — Because these cause the hardest-to-diagnose failures where everything looks healthy but traffic silently drops.

---

**NICE-TO-HAVE — Read if you have time. Less likely to be the core scenario but could come up.**

11. **Deployment/ReplicaSet/rollout mechanics (maxSurge, maxUnavailable, rollback)** — Useful if they break a rollout, but `kubectl rollout undo` is usually enough even without deep theory.
12. **Service types (ClusterIP, NodePort, LoadBalancer, ExternalName)** — Unlikely to be the bug itself, but good to know if they ask you to explain what you're seeing.
13. **Ingress (resource vs controller, IngressClass, path routing)** — Relevant if they have an Ingress layer, but it's a thinner failure surface than Services.
14. **PersistentVolumes/PVCs/StorageClasses** — Only matters if the app uses persistent storage. Know the basics (PVC Pending = no matching storage).
15. **RBAC (ServiceAccount → Role → RoleBinding)** — Rare in a 60-minute interview but worth 10 minutes of reading. Key insight: roleRef is immutable.
16. **Namespaces (what's namespaced vs cluster-scoped, cross-namespace access)** — Usually just a "gotcha" where resources are in the wrong namespace.
17. **Scheduling (taints/tolerations, affinity/anti-affinity)** — Unlikely in a hands-on troubleshooting interview. These are more system design topics.
18. **Image pull policies (Always vs IfNotPresent vs Never, tag vs digest)** — Know the basics but this is usually just "wrong image name" in practice.
19. **QoS classes and node pressure eviction** — Deep theory. Nice to mention in conversation but unlikely to be a fix-it scenario.
20. **How kubectl maps to the API** — Good for sounding knowledgeable but not essential for fixing things.

---

**VIDEO RECOMMENDATIONS**

There's no single video that covers everything, but these three together do it in under 5 hours total:

**1. TechWorld with Nana — Kubernetes Tutorial for Beginners (4 hours)**
https://www.youtube.com/watch?v=X48VuDVv0do
Covers all the core components: Pods, Services, Deployments, ConfigMaps, Secrets, Volumes, Ingress, Namespaces. Best visual explanations of how these pieces connect. Watch at 1.5x speed — you'll cover items 1, 2, 4, 6, 7, 8, 11, 12, 13, 16 from the theory list. Skip the Minikube setup and Helm sections if short on time.

**2. Learnkube — A Visual Guide on Troubleshooting Kubernetes Deployments**
https://learnkube.com/troubleshooting-deployments
Not a video, but a visual flowchart-style guide that maps directly to your playbook. Shows exactly how to trace from "app doesn't work" through Pods → Services → Ingress with diagrams. Print this or have it open during the interview. Covers items 1, 2, 3, 5, 13 from the theory list. 10-15 minutes to read.

**3. Kubernetes official docs — Debug Services page**
https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/
A step-by-step walkthrough of debugging a broken Service, written as a troubleshooting tutorial. It walks through exactly the kind of triage you'll do in the interview. Covers the health check cascade (item 20) and Service routing (item 1) in practice. 20 minutes to read.

**If you only have 2 hours:** Watch the Nana video from 0:00 to 1:30:00 at 1.5x (covers components, architecture, Services, ConfigMaps, Secrets, Deployments), then read the learnkube visual guide. That combination covers all 10 essential items at a conceptual level. Your drills with Claude Code cover the practical side.