Kubernetes Troubleshooting Interview Sheet

Use the four-part frame first. Then run the same execution loop every time:

Symptom first, root cause second.
Execution loop: classify the symptom → inspect the nearest layer/object → route by evidence → make the smallest justified fix → verify end to end. Kubernetes' own debugging docs start with triage by object or layer, and the pod lifecycle docs explicitly treat CrashLoopBackOff as an observed condition rather than the underlying cause.

---

Core frame — what to run first

1. Start

Was the Pod created, scheduled, and able to start its container?

Say: "The workload is failing before it can become a healthy running pod, so I want the scheduler/container creation signal first."

First commands:

	kubectl get pods -n <ns>
	kubectl describe pod <pod> -n <ns>
	kubectl get events -n <ns> --sort-by=.lastTimestamp

Then, depending on what you see:
	•	ErrImagePull / ImagePullBackOff → inspect image name, tag, pull secret, imagePullPolicy
	•	Pending → inspect scheduling reason, PVC, node constraints, taints/affinity
	•	CreateContainerConfigError → inspect config/secret/env refs, volume mounts
	•	Init container failure → inspect init container image, command, mounts
	•	Command / entrypoint / args problem
	•	Missing ConfigMap / Secret / volume mount
	•	PVC not binding
	•	Node capacity / taints / affinity / scheduling blockers

Docs: Debug Pods, Pod Lifecycle, Persistent Volumes, Resource Management for Pods and Containers.

2. Stay up

Did the app keep running and become Ready?

Say: "The pod exists but is not stabilising, so I want pod state, describe output, and logs before I decide what branch this belongs to."

First commands:

	kubectl get pods -n <ns>
	kubectl describe pod <pod> -n <ns>
	kubectl logs <pod> -n <ns>
	kubectl logs <pod> -n <ns> --previous

Then:
	•	CrashLoopBackOff → logs route you to actual cause (config, dep, DNS, OOM)
	•	0/1 Ready → probe path/port/startup timing
	•	Restarts climbing → liveness probe, intermittent crash, OOM
	•	OOMKilled / exit 137 → memory limit vs actual usage
	•	Error / app boot failure
	•	Startup dependency failure

Docs: Debug Running Pods, Configure Liveness Readiness and Startup Probes, Pod Lifecycle, Assign Memory Resources to Containers and Pods.

3. Receive Traffic

Can traffic reach the app through the Kubernetes routing path?

Say: "If the pod is healthy, I want to check routing layer by layer rather than guessing whether this is ingress or service."

First commands:

	kubectl get svc -n <ns>
	kubectl describe svc <service> -n <ns>
	kubectl get endpoints <service> -n <ns>
	kubectl port-forward svc/<service> 8080:<service-port> -n <ns>
	# then: curl localhost:8080/

Then:
	•	No endpoints → selector mismatch or pods not Ready
	•	Service works internally but not externally → ingress branch
	•	Wrong port → compare svc port/targetPort with container port
	•	Wrong named port
	•	Ingress host / path / backend mismatch
	•	External path broken while internal Service path works

Docs: Debug Services, Service, EndpointSlices, Ingress, Ingress Controllers.

4. Reach Dep

Can the app reach what it depends on?

Say: "The app may be up but broken against something it depends on, so I want logs and then in-container checks if needed."

First commands:

	kubectl logs <pod> -n <ns>
	kubectl describe pod <pod> -n <ns>
	kubectl exec -it <pod> -n <ns> -- sh

Then test from inside the pod:
	•	DNS → nslookup <service>.<ns>.svc.cluster.local
	•	TCP → nc -zv <host> <port> or wget -qO- http://...
	•	Env → env | grep POSTGRES (or relevant vars)
	•	Auth/RBAC → kubectl auth can-i --as=system:serviceaccount:<ns>:<sa> ...
	•	NetworkPolicy / egress restriction
	•	Storage dependency problem

Docs: DNS for Services and Pods, Debugging DNS Resolution, Network Policies, Using RBAC Authorization, Service Accounts.

---

Default triage loop

Use this when the symptom is unclear or you just sat down.

	1.	kubectl get pods -n <ns>
	2.	If pod unhealthy → kubectl describe pod <pod>, kubectl logs <pod>, kubectl logs <pod> --previous
	3.	If pod healthy → kubectl get svc + kubectl get endpoints <service>
	4.	If service works internally → check ingress / external route
	5.	If app still fails → inspect dependency path from inside pod
	6.	Make one fix
	7.	Verify end to end

---

Nearest truth source

	•	Pod not healthy → describe pod + logs
	•	Pod healthy but app unreachable → Service / endpoints
	•	Service works but external path fails → Ingress
	•	App responds but feature fails → dependency path from inside pod

---

Do not over-infer

	•	CrashLoopBackOff does not tell you the cause
	•	Running does not mean healthy
	•	Ready does not prove ingress works
	•	Existing Service does not mean it has usable endpoints
	•	Ingress object existing does not mean external routing works

---

Interview scope

Most likely: pod startup/crash, probes, config/secret/env, service selector/port/endpoints, ingress path/backend, dependency connectivity, DNS/namespace mistakes, maybe RBAC/NetworkPolicy.

Less likely: deep scheduler theory, obscure storage edge cases, advanced controller internals, node-level issues.

The symptom map below is ordered by likelihood.

---

Fast symptom map

HIGH LIKELIHOOD

Pod missing, Pending, or never becomes Running

Primary mapping: Start

First commands:

	kubectl get pods -n <ns>
	kubectl describe pod <pod> -n <ns>          # Events section: scheduling reason
	kubectl get events -n <ns> --sort-by=.lastTimestamp

What these prove: why the scheduler can't place it, or why the container can't be created.

Say: "The pod isn't even running yet, so I want the describe events to tell me whether this is scheduling, image pull, or container creation."

Then branch by what describe shows:
	•	scheduling / resource pressure → check node capacity, taints, affinity
	•	PVC / storage binding → kubectl get pvc -n <ns>
	•	image pull failure → check image spec in deployment
	•	container creation failure → check config/secret/volume refs
	•	taints / affinity / node placement → kubectl describe node

Docs: Debug Pods, Pod Lifecycle, Persistent Volumes, Resource Management for Pods and Containers.

ErrImagePull / ImagePullBackOff

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section shows the pull error
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].image}'

What these prove: the exact image reference the cluster is trying to pull, and why it can't.

Say: "The image can't be pulled, so I want to compare the image spec in the deployment against what's actually available."

Then check:
	•	wrong image name or tag → typo, wrong registry, tag doesn't exist
	•	registry auth problem → imagePullSecrets configured?
	•	pull policy → imagePullPolicy vs what's loaded locally

Docs: Debug Pods, Pod Lifecycle, Images (container images reference).

CreateContainerConfigError / CreateContainerError

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section names the broken ref
	kubectl get configmap -n <ns>
	kubectl get secret -n <ns>

What these prove: which specific ConfigMap, Secret, or volume reference is missing or invalid.

Say: "The container can't be created due to a config reference, so I need describe to tell me which Secret, ConfigMap, or volume mount is missing or wrong."

Then check:
	•	missing Secret / ConfigMap → does the named object exist?
	•	bad env reference → envFrom or valueFrom pointing at wrong key?
	•	bad volume or mount → volume name mismatch, wrong path
	•	bad command / args → entrypoint override broken

Docs: Debug Pods, Debug Running Pods, ConfigMaps, Secrets.

CrashLoopBackOff

Primary mapping: Stay up
Important: this is a symptom, not the root cause.

First commands:

	kubectl logs <pod> -n <ns>
	kubectl logs <pod> -n <ns> --previous
	kubectl describe pod <pod> -n <ns>          # Last State section: exit code, reason

What these prove: what the app printed before it died. The logs route you to the actual root cause.

Say: "CrashLoopBackOff is a symptom, not the cause. The logs will tell me what actually failed — config, dependency, DNS, OOM, or code."

Then branch by what logs show:
	•	config/env/secret error → check env vars, configmap, secret values
	•	connection refused / host not found → dependency or DNS problem (branch to Reach Dep)
	•	app stack trace / boot failure → code or entrypoint problem
	•	no logs + exit 137 → OOMKilled (check describe pod Last State)
	•	probe-driven restart → check probe config in describe

Docs: Pod Lifecycle, Debug Running Pods, Configure Liveness Readiness and Startup Probes, DNS for Services and Pods, Resource Management for Pods and Containers.

Running but 0/1 Ready

Primary mapping: Stay up

First commands:

	kubectl describe pod <pod> -n <ns>          # Conditions section + readiness probe spec
	kubectl logs <pod> -n <ns>

What these prove: the readiness probe configuration and whether the app is failing it or just not serving yet.

Say: "The container is alive but not passing readiness, so I want the probe spec from describe and any app errors from logs."

Then check:
	•	readiness probe path/port wrong → compare probe spec vs what app actually serves
	•	app boot incomplete → logs show slow startup, needs startupProbe or longer initialDelaySeconds
	•	dependency reachable enough to start but not enough to serve → partial failure in logs

Docs: Configure Liveness Readiness and Startup Probes, Debug Running Pods.

Pod healthy, but Service path fails

Primary mapping: Receive Traffic

First commands:

	kubectl get endpoints <service> -n <ns>
	kubectl describe svc <service> -n <ns>      # check selector
	kubectl get pods -n <ns> --show-labels

What these prove: whether the Service actually has backends, and whether the selector matches pod labels.

Say: "The pod looks fine, so the break is between the Service and the Pod. I want endpoints first to see if the Service selector matches."

Then check:
	•	endpoints empty → selector doesn't match pod labels, or pods are not Ready
	•	endpoints present but wrong port → compare svc port/targetPort with container port
	•	service exists but points nowhere useful → selector matches wrong pods

Docs: Debug Services, Service, EndpointSlices.

Endpoints / EndpointSlices empty or wrong

Primary mapping: Receive Traffic

First commands:

	kubectl get endpoints <service> -n <ns>
	kubectl describe svc <service> -n <ns>      # Selector field
	kubectl get pods -n <ns> --show-labels       # compare against selector

What these prove: whether the selector matches and whether matching pods are Ready.

Say: "Empty endpoints means the Service selector doesn't match any Ready pods. I want to compare the selector against actual pod labels."

Then check:
	•	selector mismatch → label key/value typo between svc and deployment
	•	pods not Ready → route to Stay up (readiness problem)
	•	backend set wrong → selector matches unintended pods

Docs: Debug Services, EndpointSlices, Service.

App responds, but feature fails when calling DB / API / storage

Primary mapping: Reach Dep

First commands:

	kubectl logs <pod> -n <ns>                          # look for connection errors
	kubectl exec -it <pod> -n <ns> -- env | grep <VAR>  # check config values
	kubectl exec -it <pod> -n <ns> -- nslookup <dep-service>.<ns>.svc.cluster.local

What these prove: whether the app has the right config and can actually reach the dependency at network level.

Say: "The app is up but something it depends on is broken. Logs will show the error, then I'll check env vars and connectivity from inside the pod."

Then check:
	•	wrong env / secret value → value exists but is wrong (typo, wrong secret key)
	•	DNS failure → hostname doesn't resolve (wrong name, wrong namespace)
	•	connection refused → dependency is down or wrong port
	•	RBAC / service account issue → kubectl auth can-i checks
	•	NetworkPolicy blocking → kubectl get networkpolicy -n <ns>

Docs: DNS for Services and Pods, Debugging DNS Resolution, Using RBAC Authorization, Service Accounts, Network Policies, Persistent Volumes.

MODERATE LIKELIHOOD

Init container failure

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>                  # Init Containers section
	kubectl logs <pod> -n <ns> -c <init-container-name>

What these prove: which init container failed and why.

Say: "The init container is blocking the main container from starting. I need its specific logs."

Then check:
	•	dependency setup failure → init container waiting for something that isn't ready
	•	bad image / command / mount → wrong image, bad script, missing volume

Docs: Debug Running Pods, Pod Lifecycle, Init Containers.

Running, Ready, but restarts increasing

Primary mapping: Stay up

First commands:

	kubectl describe pod <pod> -n <ns>          # Last State, liveness probe config, restart count
	kubectl logs <pod> -n <ns> --previous

What these prove: whether restarts are probe-driven or crash-driven, and what happened in the last run.

Say: "Restarts are climbing, so something is killing the container after it starts. I want the liveness probe config and the previous logs."

Then check:
	•	liveness probe failure → probe path/port/timing wrong
	•	intermittent crash → error in previous logs
	•	OOM → Last State shows OOMKilled, exit 137
	•	app error after boot → works at start then fails under load or after timeout

Docs: Configure Liveness Readiness and Startup Probes, Pod Lifecycle, Assign Memory Resources to Containers and Pods.

OOMKilled / exit 137

Primary mapping: Stay up

First commands:

	kubectl describe pod <pod> -n <ns>          # Last State shows OOMKilled
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].resources}'

What these prove: the memory limit vs what the app needs.

Say: "Exit 137 is OOMKilled. I want to compare the memory limit in the spec against what the app uses at startup."

Then check:
	•	memory limit too low → raise limits.memory
	•	boot spike → app allocates heavily at startup then settles
	•	no limit set but node is under pressure → kubectl describe node, check Conditions

Docs: Assign Memory Resources to Containers and Pods, Node-pressure Eviction, Pod Lifecycle.

Service works internally, external route fails

Primary mapping: Receive Traffic

First commands:

	kubectl get ingress -n <ns>
	kubectl describe ingress <ingress> -n <ns>
	kubectl get pods -n ingress-nginx            # is the controller healthy?

What these prove: whether the ingress rule is correct and the controller is running.

Say: "Internal service path works, so the break is at the ingress layer. I want the ingress spec and controller status."

Then check:
	•	wrong host / path → ingress rules don't match the request
	•	wrong backend service or port → service.name or service.port.number wrong
	•	ingress controller issue → controller pod not running or misconfigured
	•	ingressClassName missing or wrong

Docs: Ingress, Ingress Controllers, Debug Services.

"Name or service not known", lookup failures, wrong hostname behaviour

Primary mapping: Reach Dep

First commands:

	kubectl exec -it <pod> -n <ns> -- nslookup <hostname>
	kubectl exec -it <pod> -n <ns> -- cat /etc/resolv.conf
	kubectl get svc -n <ns>                     # verify actual service names

What these prove: whether the DNS name is correct and resolvable from the pod.

Say: "This is a DNS failure. I want to test resolution from inside the pod and compare the hostname against the actual service name and namespace."

Then check:
	•	bad service DNS name → typo, wrong service name
	•	wrong namespace assumption → need <svc>.<ns>.svc.cluster.local
	•	hostname correct but DNS broken → check coredns pods in kube-system

Docs: DNS for Services and Pods, Debugging DNS Resolution.

LOWER LIKELIHOOD

Forbidden / Unauthorized

Primary mapping: Reach Dep

First commands:

	kubectl describe pod <pod> -n <ns>          # check serviceAccountName
	kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>

What these prove: which service account the pod uses and what permissions it has.

Say: "This is an auth failure. I want to check which service account the pod uses and what permissions it has."

Then check:
	•	missing RBAC permission → create or fix Role/RoleBinding
	•	wrong service account → pod spec references wrong SA
	•	wrong identity assumptions → SA exists but bindings are in wrong namespace

Docs: Using RBAC Authorization, Service Accounts, Authenticating, Authorization Overview.

Traffic silently blocked despite objects looking correct

Primary mapping: Reach Dep
Sometimes also: Receive Traffic

First commands:

	kubectl get networkpolicy -n <ns>
	kubectl describe networkpolicy <policy> -n <ns>
	kubectl exec -it <pod> -n <ns> -- nc -zv <target-host> <target-port>

What these prove: whether a NetworkPolicy is blocking the traffic path.

Say: "Everything looks correct but traffic is being dropped. I want to check NetworkPolicies and test connectivity from inside the pod."

Then check:
	•	default-deny policy with no matching allow rule
	•	allow rule exists but podSelector or namespaceSelector is wrong
	•	egress policy blocking outbound traffic

Docs: Network Policies, Cluster Networking.

Rollout stuck or deployment not progressing

Primary mapping: not a root cause by itself; inspect the new Pods

First commands:

	kubectl rollout status deploy/<deploy> -n <ns>
	kubectl get replicaset -n <ns>              # is the new RS scaling up?
	kubectl get pods -n <ns>                    # are new pods stuck?

What these prove: where in the rollout the deployment is stuck.

Say: "A stuck rollout isn't the root cause — the new pods are failing. I want to find those pods and route into the right bucket."

Route to:
	•	Start, if new Pods cannot start
	•	Stay up, if new Pods crash or fail probes
	•	Receive Traffic, if Pods are healthy but not serving
	•	Reach Dep, if the app is up but broken against dependencies

Docs: Deployments, Debug Pods.

Job / CronJob issue

Primary mapping: same root-cause buckets as Pods

First commands:

	kubectl get jobs -n <ns>
	kubectl describe job <job> -n <ns>
	kubectl get pods -n <ns> --selector=job-name=<job>
	kubectl logs <job-pod> -n <ns>

What these prove: whether the job pod started, ran, and completed or failed.

Say: "I'll treat the job pod like any other pod — same triage flow applies."

Route to:
	•	Start, if Job Pod cannot start
	•	Stay up, if Job Pod crashes
	•	Reach Dep, if job logic fails against dependencies

Docs: Jobs, CronJobs, Debug Pods, Debug Running Pods.

---

Support views

Management view

Deployment → ReplicaSet → Pods

Use when asking:
	•	are the right Pods being created?
	•	is the rollout progressing?
	•	is the expected replica set actually healthy?

Docs: Deployments, ReplicaSets.

Health view

kubelet / probes → Pod / container

Use when asking:
	•	did the app start?
	•	did it stay alive?
	•	is it Ready to receive traffic?
	•	is kubelet restarting it?

Docs: Configure Liveness Readiness and Startup Probes, Pod Lifecycle, Debug Running Pods.

Traffic view

Client → Ingress → Service → EndpointSlices / endpoints → Pod → app

Use when asking:
	•	is this an internal service-routing issue or an external-routing issue?
	•	is the Service actually pointing to healthy backends?

Docs: Service, EndpointSlices, Debug Services, Ingress.

Dependencies view

Config / Secret / DNS / DB / API / storage / identity → Pod / app

Use when asking:
	•	did the app get the inputs it needs?
	•	can it reach the systems it depends on?
	•	does it have the permissions it needs?

Docs: DNS for Services and Pods, Using RBAC Authorization, Service Accounts, Persistent Volumes, Network Policies.

---

Verification commands

After any fix, verify in this order:

	1.	Pod state → kubectl get pods -n <ns>
	2.	Readiness → confirm 1/1 Ready, RESTARTS stable
	3.	Endpoints → kubectl get endpoints <service> -n <ns>
	4.	Service path → kubectl port-forward svc/<service> 8080:<port> -n <ns>, then curl localhost:8080/health
	5.	Ingress path → curl localhost/ (or curl -H "Host: <host>" http://<ingress-ip>/)
	6.	App end to end → curl localhost/health and curl localhost/items

Do not stop at "Pods are Running". Services depend on backend endpoints, and ingress only proves the external edge if the backend chain is sound.

---

What to say in the interview
	•	"I'm going to start with the symptom, not jump to a root cause."
	•	"First I want the nearest truth source."
	•	"If the Pod is broken, I'll inspect Pod state, describe output, and logs."
	•	"If the Pod is healthy, I'll move outward from Pod to Service to Ingress."
	•	"I want to make one justified change, then verify end to end."

That matches the official debugging flow and shows controlled reasoning rather than guesswork.

---

Core commands

Pods:
	kubectl get pods -n <ns>
	kubectl describe pod <pod> -n <ns>
	kubectl logs <pod> -n <ns>
	kubectl logs <pod> -n <ns> --previous

Services & Endpoints:
	kubectl get svc -n <ns>
	kubectl describe svc <service> -n <ns>
	kubectl get endpoints <service> -n <ns>

Ingress:
	kubectl get ingress -n <ns>
	kubectl describe ingress <ingress> -n <ns>

Events:
	kubectl get events -n <ns> --sort-by=.lastTimestamp

Connectivity:
	kubectl exec -it <pod> -n <ns> -- sh
	kubectl port-forward svc/<service> 8080:<port> -n <ns>

---

Most compressed version

Frame: Start → Stay up → Receive Traffic → Reach Dep
Rule: Symptom first, root cause second
Loop: classify → inspect nearest layer → route by evidence → smallest fix → verify end to end
Guard: CrashLoopBackOff ≠ cause, Running ≠ healthy, Ready ≠ ingress works, Service exists ≠ endpoints exist
