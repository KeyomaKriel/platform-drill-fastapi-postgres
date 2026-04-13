# Base template for every symptom:

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. what it rules in or rules out
3. the next 1–2 commands to confirm
4. the smallest justified fix if the evidence is already sufficient

Do not guess beyond the evidence.

Symptom: <symptom>

Output:
<paste raw command output here>

That fits the sheet’s pattern of symptom first, nearest truth source second, then route by evidence.  ￼  ￼

Now the symptom-specific versions.

1. Nothing looks right / expected objects seem missing

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this looks like wrong context, wrong namespace, wrong object name, or a real workload problem
2. the key signal
3. the next 1–2 commands
4. what I should check next

Do not guess beyond the evidence.

Symptom: Nothing looks right / expected objects seem missing

Output:
<paste raw command output here>

2. No pod / expected pod missing

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether the Deployment is missing, scaled to zero, or failing to create pods
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: No pod / expected pod missing

Output:
<paste raw command output here>

3. Pod Pending

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to scheduling pressure, taints/affinity, node placement, or PVC/storage
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Pod Pending

Output:
<paste raw command output here>

4. Pod stuck ContainerCreating / image pull / create config error

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. which container creation step is failing
2. whether this looks like image pull, config/secret/env, or volume related
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Pod stuck ContainerCreating / image pull / create config error

Output:
<paste raw command output here>

5. ErrImagePull / ImagePullBackOff

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this looks like wrong image name/tag, registry auth, or pull policy
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix

Do not guess beyond the evidence.

Symptom: ErrImagePull / ImagePullBackOff

Output:
<paste raw command output here>

6. CreateContainerConfigError / CreateContainerError

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to missing ConfigMap/Secret, bad env key/reference, bad volume/mount, or broken command/args
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix

Do not guess beyond the evidence.

Symptom: CreateContainerConfigError / CreateContainerError

Output:
<paste raw command output here>

7. CrashLoopBackOff

Interpret this Kubernetes troubleshooting output concisely.

Treat CrashLoopBackOff as a symptom, not the root cause.

Tell me:
1. the most important signal from logs / previous logs / describe
2. whether this points more to config/env, dependency, DNS, OOMKilled, probe failure, or app startup crash
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: CrashLoopBackOff

Output:
<paste raw command output here>

8. Running but 0/1 Ready

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether readiness is failing due to wrong probe path, wrong probe port, startup timing, or a real app problem
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Running but 0/1 Ready

Output:
<paste raw command output here>

9. Pod Running/Ready, but Service path fails

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to selector mismatch, empty endpoints, wrong targetPort, wrong named port, or wrong backend pods
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Pod Running/Ready, but Service path fails

Output:
<paste raw command output here>

10. Endpoints / EndpointSlices empty or wrong

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to selector mismatch, pods not Ready, or the Service selecting the wrong backend
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Endpoints / EndpointSlices empty or wrong

Output:
<paste raw command output here>

11. App responds, but feature fails when calling DB / API / storage

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points more to wrong env/config, DNS, connection refused, RBAC/service account, NetworkPolicy, or storage dependency failure
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: App responds, but feature fails when calling DB / API / storage

Output:
<paste raw command output here>

12. Init container failure

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. which init container is failing
2. whether this looks like dependency wait failure, bad image/command, or missing mount/config
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Init container failure

Output:
<paste raw command output here>

13. Running, Ready, but restarts increasing

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether restarts look probe-driven, crash-driven, or OOM-related
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Running, Ready, but restarts increasing

Output:
<paste raw command output here>

14. OOMKilled / exit 137

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this looks like memory limit too low, startup memory spike, or node pressure
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix

Do not guess beyond the evidence.

Symptom: OOMKilled / exit 137

Output:
<paste raw command output here>

15. Service works internally, external route fails

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to ingress host/path mismatch, wrong backend service/port, bad ingressClassName, or ingress controller health
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Service works internally, external route fails

Output:
<paste raw command output here>

16. “Name or service not known”, lookup failures, wrong hostname behaviour

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to wrong service name, wrong namespace assumption, missing FQDN, or real cluster DNS trouble
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Name or service not known / lookup failures / wrong hostname behaviour

Output:
<paste raw command output here>

17. App runs, but behaviour does not match the expected version

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this looks like wrong image tag, stale mutable tag, or image built from the wrong code/context
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix

Do not guess beyond the evidence.

Symptom: App runs, but behaviour does not match the expected version

Output:
<paste raw command output here>

18. Pod is Running, but app only works from inside the container

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to binding on 127.0.0.1 instead of 0.0.0.0, wrong containerPort, or wrong path/port assumptions
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Pod is Running, but app only works from inside the container

Output:
<paste raw command output here>

19. Logs are confusing or empty in a multi-container pod

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether I am looking at the wrong container
2. whether the failing container is the app container, sidecar, or init container
3. the next 1–2 commands
4. what output would confirm the right logging target

Do not guess beyond the evidence.

Symptom: Logs are confusing or empty in a multi-container pod

Output:
<paste raw command output here>

20. Forbidden / Unauthorized

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to missing RBAC permission, wrong service account, or bindings in the wrong namespace
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Forbidden / Unauthorized

Output:
<paste raw command output here>

21. Traffic silently blocked despite objects looking correct

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether this points to NetworkPolicy blocking ingress or egress
2. the key signal
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Traffic silently blocked despite objects looking correct

Output:
<paste raw command output here>

22. Rollout stuck or deployment not progressing

Interpret this Kubernetes troubleshooting output concisely.

Treat this as a routing symptom, not the root cause.

Tell me:
1. where the rollout is stuck
2. whether this should route to Start, Stay Up, Receive Traffic, or Reach Dep
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Rollout stuck or deployment not progressing

Output:
<paste raw command output here>

23. Job / CronJob issue

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. whether the job pod cannot start, crashes while running, or fails against a dependency
2. which bucket this routes into
3. the next 1–2 commands
4. the smallest justified fix if already clear

Do not guess beyond the evidence.

Symptom: Job / CronJob issue

Output:
<paste raw command output here>



# Base failure domain template:

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this really belongs in this failure domain
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix if the evidence is already sufficient

Do not guess beyond the evidence.

Domain: <failure domain>

Output:
<paste raw command output here>

Now the actual domain prompts.

1. Startup / Crash

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal from logs / previous logs / describe
2. whether this is really an app startup crash rather than config, dependency, probe, or OOM
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix if the evidence is already sufficient

Do not guess beyond the evidence.

Domain: Startup / Crash

Output:
<paste raw command output here>

2. Image Pull / Container Creation

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is image pull, missing image auth, imagePullPolicy, or container creation/config failure
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Image Pull / Container Creation

Output:
<paste raw command output here>

3. Probe Failure

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is readiness, liveness, or startup probe failure
3. whether the likely issue is wrong path, wrong port, bad timing, or a real app problem
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Probe Failure

Output:
<paste raw command output here>

4. Config / Secret / Env

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is missing ConfigMap/Secret, wrong reference name, wrong key, or wrong injected value
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Config / Secret / Env

Output:
<paste raw command output here>

5. Service Routing / Port / Endpoint

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is selector mismatch, empty endpoints, wrong targetPort, wrong named port, or wrong backend pods
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Service Routing / Port / Endpoint

Output:
<paste raw command output here>

6. DNS / Service Discovery / Namespace

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is wrong namespace, wrong service name, missing FQDN, or cluster DNS trouble
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: DNS / Service Discovery / Namespace

Output:
<paste raw command output here>

7. Resource / Scheduling / Storage

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is scheduling pressure, taints/affinity, node placement, OOMKilled, or PVC/storage binding
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Resource / Scheduling / Storage

Output:
<paste raw command output here>

8. Ingress / External Routing

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is wrong host/path rule, wrong backend service/port, bad ingressClassName, or ingress controller health
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Ingress / External Routing

Output:
<paste raw command output here>

9. App-Level dependency failure

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is dependency down, wrong host/port, connection refused, partial startup dependency failure, or app logic failing against the dependency
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: App-Level dependency failure

Output:
<paste raw command output here>

10. RBAC

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is missing permission, wrong service account, or binding in the wrong namespace
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: RBAC

Output:
<paste raw command output here>

11. NetworkPolicy

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is ingress blocking, egress blocking, default-deny with no matching allow, or a selector mismatch in the policy
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: NetworkPolicy

Output:
<paste raw command output here>

These domains match the structure in your sheet: startup/crash, image pull/container creation, probe failure, config/secret/env, service routing/port/endpoint, DNS/service discovery/namespace, resource/scheduling/storage, plus the routing branches to ingress, app-level dependency failure, RBAC, and NetworkPolicy.  ￼  ￼

Best use in the interview:
	•	Start with the symptom prompt
	•	Switch to one of these only when the output clearly points there
	•	Keep the pasted output raw
	•	Then explain the next step in your own words

The one mistake to avoid is jumping straight to a domain too early. Your own sheet is explicit that things like CrashLoopBackOff are only symptoms, not causes.  ￼

I can compress these 11 into ultra-short one-line prompts next.Yes. Here is the tight second-layer set for the main failure domains.

Use these only after the evidence already points to the domain. That matches your sheet’s flow: symptom first, nearest truth source next, then route by evidence into a failure domain.  ￼

Base visible-safe domain template:

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this really belongs in this failure domain
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix if the evidence is already sufficient

Do not guess beyond the evidence.

Domain: <failure domain>

Output:
<paste raw command output here>

Now the actual domain prompts.

1. Startup / Crash

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal from logs / previous logs / describe
2. whether this is really an app startup crash rather than config, dependency, probe, or OOM
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix if the evidence is already sufficient

Do not guess beyond the evidence.

Domain: Startup / Crash

Output:
<paste raw command output here>

2. Image Pull / Container Creation

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is image pull, missing image auth, imagePullPolicy, or container creation/config failure
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Image Pull / Container Creation

Output:
<paste raw command output here>

3. Probe Failure

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is readiness, liveness, or startup probe failure
3. whether the likely issue is wrong path, wrong port, bad timing, or a real app problem
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Probe Failure

Output:
<paste raw command output here>

4. Config / Secret / Env

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is missing ConfigMap/Secret, wrong reference name, wrong key, or wrong injected value
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Config / Secret / Env

Output:
<paste raw command output here>

5. Service Routing / Port / Endpoint

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is selector mismatch, empty endpoints, wrong targetPort, wrong named port, or wrong backend pods
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Service Routing / Port / Endpoint

Output:
<paste raw command output here>

6. DNS / Service Discovery / Namespace

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is wrong namespace, wrong service name, missing FQDN, or cluster DNS trouble
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: DNS / Service Discovery / Namespace

Output:
<paste raw command output here>

7. Resource / Scheduling / Storage

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is scheduling pressure, taints/affinity, node placement, OOMKilled, or PVC/storage binding
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Resource / Scheduling / Storage

Output:
<paste raw command output here>

8. Ingress / External Routing

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is wrong host/path rule, wrong backend service/port, bad ingressClassName, or ingress controller health
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: Ingress / External Routing

Output:
<paste raw command output here>

9. App-Level dependency failure

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is dependency down, wrong host/port, connection refused, partial startup dependency failure, or app logic failing against the dependency
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: App-Level dependency failure

Output:
<paste raw command output here>

10. RBAC

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is missing permission, wrong service account, or binding in the wrong namespace
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: RBAC

Output:
<paste raw command output here>

11. NetworkPolicy

Interpret this Kubernetes troubleshooting output concisely.

Tell me:
1. the key signal
2. whether this is ingress blocking, egress blocking, default-deny with no matching allow, or a selector mismatch in the policy
3. what it rules in or rules out
4. the next 1–2 commands to confirm
5. the smallest justified fix

Do not guess beyond the evidence.

Domain: NetworkPolicy

Output:
<paste raw command output here>

