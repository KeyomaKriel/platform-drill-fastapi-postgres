Kubernetes Troubleshooting Interview Sheet

Use the four-part frame first. Then run the same execution loop every time:

Symptom first, root cause second.
Execution loop: classify the symptom → inspect the nearest layer/object → route by evidence → make the smallest justified fix → verify end to end. Kubernetes' own debugging docs start with triage by object or layer, and the pod lifecycle docs explicitly treat CrashLoopBackOff as an observed condition rather than the underlying cause.

---

Default triage loop

Use this when the symptom is unclear or you just sat down.

	1.	kubectl get pods -n <ns>
	2.	kubectl get deploy -n <ns>
	3.	If pod unhealthy → kubectl describe pod <pod>, kubectl logs <pod>, kubectl logs <pod> --previous
	4.	If deployment not progressing → kubectl describe deploy <deploy> -n <ns>, kubectl rollout status deploy/<deploy> -n <ns>
	5.	If pod Running/Ready → kubectl get svc + kubectl get endpoints <service>
	6.	If service works internally → check ingress / external route
	7.	If app still fails → inspect dependency path from inside pod
	8.	Make one fix
	9.	Verify end to end

---

Nearest truth source

	•	Pod not running → describe pod + logs
	•	Deployment not progressing → describe deploy + rollout status
	•	Pod Running/Ready but app unreachable → Service / endpoints
	•	Service works but external path fails → Ingress
	•	App responds but feature fails → dependency path from inside pod

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

Say: "If the pod is Running and Ready, I want to check routing layer by layer rather than guessing whether this is ingress or service."

First commands:

	kubectl get svc -n <ns>
	kubectl describe svc <service> -n <ns>
	kubectl get endpoints <service> -n <ns>
	kubectl port-forward svc/<service> 8080:<service-port> -n <ns>
	# then: curl localhost:8080/<path>

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

Do not over-infer

	•	CrashLoopBackOff does not tell you the cause
	•	Running does not mean healthy
	•	Ready does not prove ingress works
	•	Existing Service does not mean it has usable endpoints
	•	Ingress object existing does not mean external routing works

---

Fast symptom map

HIGH LIKELIHOOD

No pod / expected pod missing

Primary mapping: Start

First commands:

	kubectl get pods -n <ns>
	kubectl get deploy -n <ns>
	kubectl describe deploy <deploy> -n <ns>

What these usually reveal: whether the Deployment exists and is creating pods, or whether the workload is missing entirely.

Say: "I don't see the expected pod, so I want to check whether the Deployment exists and what its status is — wrong namespace, scaling issue, or not created."

Then check:
	•	Deployment missing or not found → wrong namespace, not applied, deleted
	•	Deployment exists but 0 replicas → check spec.replicas, or check if scaled to zero
	•	Deployment exists but ReplicaSet not creating pods → kubectl get rs -n <ns>, check events
	•	Wrong labels or selectors → pod template labels don't match

Docs: Deployments, ReplicaSets, Debug Pods.

Pod Pending

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section: scheduling reason
	kubectl get events -n <ns> --sort-by=.lastTimestamp

What these usually reveal: why the scheduler can't place the pod.

Say: "The pod exists but is Pending, so the scheduler can't place it. Describe events will tell me whether this is resources, taints, affinity, or storage."

Then branch by what describe shows:
	•	scheduling / resource pressure → check node capacity, taints, affinity
	•	PVC / storage binding → kubectl get pvc -n <ns>
	•	taints / affinity / node placement → kubectl describe node

Docs: Debug Pods, Pod Lifecycle, Persistent Volumes, Resource Management for Pods and Containers.

Pod stuck ContainerCreating / image pull / create config error

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section names the specific failure
	kubectl get events -n <ns> --sort-by=.lastTimestamp

What these usually reveal: which container creation step is failing and why.

Say: "The pod is scheduled but the container can't start. Describe events will tell me whether this is an image pull, config reference, or volume problem."

Then branch by what describe shows:
	•	image pull failure → check image spec in deployment (see ErrImagePull section below)
	•	container creation failure → check config/secret/volume refs (see CreateContainerConfigError section below)

Docs: Debug Pods, Pod Lifecycle, Images, ConfigMaps, Secrets.

ErrImagePull / ImagePullBackOff

Primary mapping: Start

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section shows the pull error
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].image}'

What these usually reveal: the exact image reference the cluster is trying to pull, and why it can't.

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

What these usually reveal: which specific ConfigMap, Secret, or volume reference is missing or invalid.

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

What these usually reveal: what the app printed before it died. The logs route you to the actual root cause.

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

What these usually reveal: the readiness probe configuration and whether the app is failing it or just not serving yet.

Say: "The container is alive but not passing readiness, so I want the probe spec from describe and any app errors from logs."

Then check:
	•	readiness probe path/port wrong → compare probe spec vs what app actually serves
	•	app boot incomplete → logs show slow startup, needs startupProbe or longer initialDelaySeconds
	•	dependency reachable enough to start but not enough to serve → partial failure in logs

Docs: Configure Liveness Readiness and Startup Probes, Debug Running Pods.

Pod Running/Ready, but Service path fails

Primary mapping: Receive Traffic

First commands:

	kubectl get endpoints <service> -n <ns>
	kubectl describe svc <service> -n <ns>      # check selector
	kubectl get pods -n <ns> --show-labels

What these usually reveal: whether the Service actually has backends, and whether the selector matches pod labels.

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

What these usually reveal: whether the selector matches and whether matching pods are Ready.

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

What these usually reveal: whether the app has the right config and can actually reach the dependency at network level.

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

What these usually reveal: which init container failed and why.

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

What these usually reveal: whether restarts are probe-driven or crash-driven, and what happened in the last run.

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

What these usually reveal: the memory limit vs what the app needs.

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

What these usually reveal: whether the ingress rule is correct and the controller is running.

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

What these usually reveal: whether the DNS name is correct and resolvable from the pod.

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

What these usually reveal: which service account the pod uses and what permissions it has.

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

What these usually reveal: whether a NetworkPolicy is blocking the traffic path.

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

What these usually reveal: where in the rollout the deployment is stuck.

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

What these usually reveal: whether the job pod started, ran, and completed or failed.

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
	•	"If the Pod is Running and Ready, I'll move outward from Pod to Service to Ingress."
	•	"I want to make one justified change, then verify end to end."

That matches the official debugging flow and shows controlled reasoning rather than guesswork.

---

Core commands

Pods:
	kubectl get pods -n <ns>
	kubectl describe pod <pod> -n <ns>
	kubectl logs <pod> -n <ns>
	kubectl logs <pod> -n <ns> --previous

Deployments:
	kubectl get deploy -n <ns>
	kubectl describe deploy <deploy> -n <ns>
	kubectl rollout status deploy/<deploy> -n <ns>

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

Receive Traffic:
    Test the app directly

kubectl port-forward pod/<pod> 8080:<app-port> -n <ns>
curl http://localhost:8080/

If this fails, the problem is not Ingress or Service. Go back to pod/app/probes/config.

If pod test works, test the Service

kubectl port-forward svc/<service> 8080:<service-port> -n <ns>
curl http://localhost:8080/

If this fails, check selector, endpoints, targetPort, readiness.

If Service test works, test Ingress

kubectl port-forward svc/<ingress-controller-service> 8080:80 -n ingress-nginx
curl -H "Host: <host-from-ingress>" http://localhost:8080/

If this fails, check host, path, backend service, backend port, ingressClassName, controller.

---

Most compressed version

Frame: Start → Stay up → Receive Traffic → Reach Dep
Rule: Symptom first, root cause second
Loop: classify → inspect nearest layer → route by evidence → smallest fix → verify end to end
Guard: CrashLoopBackOff ≠ cause, Running ≠ healthy, Ready ≠ ingress works, Service exists ≠ endpoints exist

---

Fix / Resolution Sections

Multiple symptom branches converge on the same underlying fix. Each section below is referenced by the symptom map above. After any fix, run the verification commands section to confirm the full path works end to end.

---

Fix: Image pull failure

What it usually means: The image reference in the Deployment spec doesn't match what's available — wrong name, wrong tag, missing from registry, or wrong pull policy for a locally loaded image.

First commands:

	kubectl describe pod <pod> -n <ns>
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].image}'
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'

Likely fixes:
	•	Wrong image name or tag → fix the image field in the Deployment spec
	•	Image loaded locally but imagePullPolicy is Always → set to IfNotPresent or Never
	•	Private registry without credentials → add imagePullSecrets to the pod spec
	•	For kind/local clusters → verify image is loaded: kind load docker-image <image> --name <cluster>

Fix commands:

	# Fix in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Load image into kind (local clusters only)
	kind load docker-image <image>:<tag> --name <cluster>

	# Or fix imperatively
	kubectl set image deploy/<deploy> <container>=<correct-image>:<tag> -n <ns>
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"IfNotPresent"}]'

Verification:

	kubectl rollout status deploy/<deploy> -n <ns>
	kubectl get pods -n <ns>    # should transition from ErrImagePull to Running

Docs: Images, Debug Pods, Pod Lifecycle.

---

Fix: Config / Secret / volume reference

What it usually means: The pod spec references a ConfigMap, Secret, or volume that doesn't exist, or references a key that doesn't exist in an object that does.

First commands:

	kubectl describe pod <pod> -n <ns>          # Events section names the broken ref
	kubectl get configmap -n <ns>
	kubectl get secret -n <ns>

Likely fixes:
	•	Referenced ConfigMap or Secret doesn't exist → create it, or fix the name in the pod spec
	•	envFrom or valueFrom points at a key that doesn't exist → fix the key name or add the key to the object
	•	Volume references a non-existent ConfigMap/Secret → fix the volume definition
	•	Optional: false (default) on a missing ref → either create the object or mark the ref optional: true if appropriate

Fix commands:

	# Fix the reference in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# If the ConfigMap or Secret itself is missing, create it from its manifest
	# (or create imperatively if no manifest exists)
	kubectl create configmap <cm> --from-literal=<key>=<value> -n <ns>
	kubectl create secret generic <secret> --from-literal=<key>=<value> -n <ns>

	# Or patch inline
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/envFrom/0/configMapRef/name","value":"<correct-cm>"}]'

Verification:

	kubectl get pods -n <ns>    # should clear CreateContainerConfigError
	kubectl describe pod <pod> -n <ns>    # no config-related errors in Events

Docs: ConfigMaps, Secrets, Debug Pods.

---

Fix: Config / Secret values

What it usually means: The ConfigMap or Secret exists and the reference is valid, but the actual data value is wrong — a typo, wrong hostname, wrong port, wrong password, or wrong key mapping.

First commands:

	kubectl exec -it <pod> -n <ns> -- env | grep <VAR>
	kubectl get configmap <cm> -n <ns> -o yaml
	kubectl get secret <secret> -n <ns> -o jsonpath='{.data.<key>}' | base64 -d

Likely fixes:
	•	Wrong value in ConfigMap → kubectl edit configmap <cm> -n <ns> or patch it
	•	Wrong value in Secret → fix and re-apply (remember base64 encoding)
	•	Env var mapped to wrong key → fix the valueFrom.key reference in the Deployment
	•	After fixing ConfigMap/Secret data, the pod must be restarted to pick up changes (unless using mounted volumes with auto-refresh)

Fix commands:

	# Fix the value in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Restart pods to pick up the new values
	kubectl rollout restart deploy/<deploy> -n <ns>

	# Or patch imperatively
	kubectl patch configmap <cm> -n <ns> --type=merge \
	  -p '{"data":{"<key>":"<correct-value>"}}'
	kubectl patch secret <secret> -n <ns> --type=merge \
	  -p '{"data":{"<key>":"<base64-encoded-value>"}}'

Verification:

	kubectl rollout restart deploy/<deploy> -n <ns>
	kubectl exec -it <new-pod> -n <ns> -- env | grep <VAR>    # confirm correct value
	kubectl logs <new-pod> -n <ns>    # confirm app starts without config errors

Docs: ConfigMaps, Secrets, Debug Running Pods.

---

Fix: Probe configuration

What it usually means: A readiness, liveness, or startup probe is misconfigured — wrong path, wrong port, or timing too aggressive for the app's boot time.

First commands:

	kubectl describe pod <pod> -n <ns>          # probe spec + Conditions section
	kubectl logs <pod> -n <ns>

Likely fixes:
	•	Wrong probe path → fix httpGet.path to match what the app actually serves (e.g. /health not /healthz)
	•	Wrong probe port → fix httpGet.port or tcpSocket.port to match the container port
	•	App too slow to boot → add a startupProbe with generous failureThreshold, or increase initialDelaySeconds
	•	Liveness killing before ready → increase liveness initialDelaySeconds or periodSeconds, or add a startupProbe to cover boot time
	•	Readiness probe correct but app genuinely not ready → route to dependency or config fix

Fix commands:

	# Fix probe config in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or patch imperatively
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/<correct-path>"}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/port","value":<correct-port>}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/initialDelaySeconds","value":<seconds>}]'

Verification:

	kubectl get pods -n <ns>    # should show 1/1 Ready, RESTARTS stable
	kubectl describe pod <pod> -n <ns>    # Conditions: Ready True

Docs: Configure Liveness Readiness and Startup Probes, Pod Lifecycle.

---

Fix: App startup / entrypoint failure

What it usually means: The container starts but the process exits immediately — bad command/args override, wrong entrypoint, missing startup dependency, failed migration, or unhandled exception during boot. Logs exist but the container never reaches steady state.

First commands:

	kubectl logs <pod> -n <ns>
	kubectl logs <pod> -n <ns> --previous
	kubectl describe pod <pod> -n <ns>          # Last State: exit code, command/args spec
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].command}'
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].args}'

Likely fixes:
	•	Wrong command or args in Deployment spec → fix or remove the override so the Dockerfile entrypoint runs
	•	Entrypoint overridden accidentally → command in the pod spec replaces ENTRYPOINT; args replaces CMD. Remove the override if the Dockerfile is correct
	•	Startup migration or seed script fails → fix the script, or fix the dependency it needs (DB not ready, wrong credentials). Check logs for the specific error
	•	Unhandled exception at boot → logs show the stack trace. Fix the app code or the config it depends on
	•	Missing startup dependency with no retry → app crashes because a dependency isn't ready yet. Add an init container that waits, or add retry logic
	•	Wrong working directory or missing file → command references a path that doesn't exist in the image. Check the Dockerfile and the command

Fix commands:

	# Fix or remove command/args in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or patch imperatively
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"remove","path":"/spec/template/spec/containers/0/command"}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"remove","path":"/spec/template/spec/containers/0/args"}]'

Verification:

	kubectl rollout restart deploy/<deploy> -n <ns>    # or re-apply after fix
	kubectl get pods -n <ns>    # Running, RESTARTS not climbing
	kubectl logs <pod> -n <ns>    # clean startup, no stack trace

Docs: Debug Running Pods, Pod Lifecycle, Define a Command and Arguments for a Container.

---

Fix: Init container failure

What it usually means: An init container is blocking the main container from starting — it's crashing, waiting on an unmet condition, or misconfigured.

First commands:

	kubectl describe pod <pod> -n <ns>          # Init Containers section: state, exit code, image, command
	kubectl logs <pod> -n <ns> -c <init-container-name>

Likely fixes:
	•	Init container image wrong → fix the image reference (same as image pull fix, but check the initContainers array specifically)
	•	Bad command or script → fix the command/args in the init container spec. Check logs for the exact error
	•	Waiting for a dependency that isn't ready → the init container is doing a wait loop (e.g. waiting for a database). Fix the dependency first, or fix the hostname/port the init container is checking
	•	Missing ConfigMap/Secret/volume mount → same as config reference fix, but check the init container's env and volumeMounts separately from the main container
	•	Wrong permissions or working directory → init container runs as a different user or in a different context than expected

Fix commands:

	# Fix in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or patch imperatively
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/initContainers/0/image","value":"<correct-image>:<tag>"}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/initContainers/0/command","value":["sh","-c","<corrected-command>"]}]'

Verification:

	kubectl describe pod <pod> -n <ns>    # Init Containers: all show State: Terminated, Reason: Completed
	kubectl get pods -n <ns>    # pod progresses past Init to Running

Docs: Init Containers, Debug Running Pods, Pod Lifecycle.

---

Fix: Memory limits (OOMKilled)

What it usually means: The container's memory limit is lower than what the app needs, especially at startup.

First commands:

	kubectl describe pod <pod> -n <ns>          # Last State: OOMKilled
	kubectl get deploy <deploy> -n <ns> -o jsonpath='{.spec.template.spec.containers[0].resources}'

Likely fixes:
	•	Memory limit too low → increase resources.limits.memory in the Deployment spec
	•	No memory limit but node under pressure → set an explicit limit above the app's peak usage
	•	App has a startup spike → set limit to cover the spike, or fix the app's boot memory profile
	•	Also check requests — if requests > node capacity, pods won't schedule

Fix commands:

	# Fix resource limits in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or patch imperatively
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"<value>"}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"<value>"}]'

Verification:

	kubectl rollout status deploy/<deploy> -n <ns>
	kubectl get pods -n <ns>    # Running, no OOMKilled in describe Last State
	kubectl describe pod <pod> -n <ns>    # Last State: Running (not Terminated/OOMKilled)

Docs: Assign Memory Resources to Containers and Pods, Resource Management for Pods and Containers.

---

Fix: Service selector and port mapping

What it usually means: The Service selector doesn't match the pod labels, or the port/targetPort mapping is wrong, so the Service has no usable endpoints.

First commands:

	kubectl describe svc <service> -n <ns>      # Selector and Ports
	kubectl get pods -n <ns> --show-labels
	kubectl get endpoints <service> -n <ns>

Likely fixes:
	•	Selector mismatch → fix the Service selector to match the pod labels (or vice versa, fix the Deployment labels)
	•	targetPort wrong → set targetPort to the port the container actually listens on
	•	Port wrong → set the Service port to what clients expect
	•	Named port mismatch → ensure the port name in the Service matches the container port name
	•	Pods not Ready → fix readiness (route to probe fix) so they appear in endpoints

Fix commands:

	# Fix in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or patch imperatively
	kubectl patch svc <service> -n <ns> --type=merge \
	  -p '{"spec":{"selector":{"<label-key>":"<label-value>"}}}'
	kubectl patch svc <service> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/ports/0/targetPort","value":<correct-port>}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/metadata/labels/<label-key>","value":"<label-value>"}]'

Verification:

	kubectl get endpoints <service> -n <ns>    # should list pod IPs
	kubectl port-forward svc/<service> 8080:<port> -n <ns>
	curl localhost:8080/<path>    # confirm Service routes to the app

Docs: Service, EndpointSlices, Debug Services.

---

Fix: Ingress routing

What it usually means: The Ingress object exists but its rules don't route traffic to the backend correctly — wrong host, wrong path, wrong service reference, or the controller isn't running.

First commands:

	kubectl describe ingress <ingress> -n <ns>
	kubectl get pods -n ingress-nginx
	kubectl get svc -n <ns>

Likely fixes:
	•	Wrong host → fix the host field, or remove it to match any host
	•	Wrong path → fix the path or pathType (Prefix vs Exact)
	•	Wrong backend service name or port → fix service.name and service.port.number to match the actual Service
	•	ingressClassName missing or wrong → add or fix ingressClassName (e.g. nginx)
	•	Ingress controller not running → check controller pod, restart if crashed, verify it's installed

Fix commands:

	# Fix backend service name or port in Ingress (edit manifest and re-apply)
	vi <ingress-manifest>
	kubectl apply -f <ingress-manifest> -n <ns>

	# Or patch inline — fix backend service port
	kubectl patch ingress <ingress> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/port/number","value":<correct-port>}]'

	# Fix backend service name
	kubectl patch ingress <ingress> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/rules/0/http/paths/0/backend/service/name","value":"<correct-service>"}]'

	# Fix ingressClassName
	kubectl patch ingress <ingress> -n <ns> --type=merge \
	  -p '{"spec":{"ingressClassName":"<class>"}}'

Verification:

	# 1. Confirm the ingress controller is running
	kubectl get pods -n ingress-nginx
	# 2. Confirm the ingress object has an ADDRESS assigned
	kubectl get ingress -n <ns>
	# 3. Test through the ingress using the correct host header and ingress address
	#    Local cluster with host port mapping:
	curl localhost/
	#    Remote or LoadBalancer setup:
	curl -H "Host: <host>" http://<ingress-address>/
	# 4. Verify app endpoints through the external path
	curl <same-base>/<path>
	curl <same-base>/<path>

Docs: Ingress, Ingress Controllers.

---

Fix: DNS / service discovery

What it usually means: The app is using a hostname that doesn't resolve — typo in service name, wrong namespace, or DNS infrastructure is broken.

First commands:

	kubectl exec -it <pod> -n <ns> -- nslookup <hostname>
	kubectl exec -it <pod> -n <ns> -- cat /etc/resolv.conf
	kubectl get svc --all-namespaces | grep <expected-name>

Likely fixes:
	•	Typo in service name → fix the hostname in the app config or env var
	•	Wrong namespace → use the fully qualified name: <service>.<namespace>.svc.cluster.local
	•	Service doesn't exist → create it
	•	CoreDNS broken → check coredns pods in kube-system: kubectl get pods -n kube-system -l k8s-app=kube-dns

Fix commands:

	# Fix the hostname in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Restart pods to pick up the corrected value
	kubectl rollout restart deploy/<deploy> -n <ns>

	# Or patch imperatively
	kubectl patch configmap <cm> -n <ns> --type=merge \
	  -p '{"data":{"<host-key>":"<correct-service>.<ns>.svc.cluster.local"}}'
	kubectl patch secret <secret> -n <ns> --type=merge \
	  -p '{"data":{"<host-key>":"<base64-encoded-correct-hostname>"}}'

	# Restart CoreDNS if it's unhealthy
	kubectl rollout restart deploy/coredns -n kube-system

Verification:

	kubectl exec -it <pod> -n <ns> -- nslookup <corrected-hostname>
	kubectl logs <pod> -n <ns>    # no more "name or service not known"

Docs: DNS for Services and Pods, Debugging DNS Resolution.

---

Fix: Dependency connectivity

What it usually means: DNS resolves correctly but the connection fails — the dependency is down, the port is wrong, or a NetworkPolicy is blocking traffic.

First commands:

	kubectl exec -it <pod> -n <ns> -- nc -zv <host> <port>
	kubectl logs <pod> -n <ns>
	kubectl get pods -n <ns>    # is the dependency pod running?

Likely fixes:
	•	Dependency pod not running → fix the dependency first (same triage flow)
	•	Wrong port in app config → fix the port env var or ConfigMap value
	•	NetworkPolicy blocking → route to NetworkPolicy fix below
	•	Dependency running but not accepting connections → check dependency logs and readiness

Fix commands:

	# Fix the config value in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Restart the app to pick up the corrected config
	kubectl rollout restart deploy/<deploy> -n <ns>

	# Or patch imperatively
	kubectl patch configmap <cm> -n <ns> --type=merge \
	  -p '{"data":{"<port-key>":"<correct-port>"}}'

	# If the dependency itself is down, triage it the same way
	kubectl describe pod <dep-pod> -n <ns>
	kubectl logs <dep-pod> -n <ns>

Verification:

	kubectl exec -it <pod> -n <ns> -- nc -zv <host> <port>    # should succeed
	kubectl logs <pod> -n <ns>    # no connection errors

Docs: Network Policies, Debug Services, Debug Running Pods.

---

Fix: NetworkPolicy rules

What it usually means: A default-deny policy exists and the allow rules don't match the traffic path — wrong selectors, missing rules, or egress blocked.

First commands:

	kubectl get networkpolicy -n <ns>
	kubectl describe networkpolicy <policy> -n <ns>
	kubectl get pods -n <ns> --show-labels

Likely fixes:
	•	Default-deny with no allow rule for the traffic path → add an ingress or egress allow rule
	•	Allow rule exists but podSelector is wrong → fix the label selector to match the source/target pods
	•	Allow rule exists but namespaceSelector is wrong → fix to match the source namespace
	•	Egress policy blocking outbound → add egress allow for the destination
	•	DNS blocked by egress policy → ensure egress allows UDP 53 to kube-system (CoreDNS)

Fix commands:

	# Fix a podSelector in an existing NetworkPolicy (edit manifest and re-apply)
	vi <networkpolicy-manifest>
	kubectl apply -f <networkpolicy-manifest> -n <ns>

	# Or patch inline — fix a podSelector on an ingress rule
	kubectl patch networkpolicy <policy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/ingress/0/from/0/podSelector/matchLabels/<key>","value":"<value>"}]'

	# Delete a policy that's blocking traffic entirely (if the fix is to remove it)
	kubectl delete networkpolicy <policy> -n <ns>

Verification:

	kubectl exec -it <pod> -n <ns> -- nc -zv <target-host> <target-port>    # should succeed
	kubectl exec -it <pod> -n <ns> -- nslookup <hostname>    # DNS still works

Docs: Network Policies, Cluster Networking.

---

Fix: RBAC / service account

What it usually means: The pod's service account doesn't have the permissions the app needs — missing Role, missing RoleBinding, or wrong service account assigned.

First commands:

	kubectl describe pod <pod> -n <ns>          # serviceAccountName
	kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>
	kubectl get rolebinding -n <ns>

Likely fixes:
	•	Missing Role → create a Role with the required permissions
	•	Missing RoleBinding → create a RoleBinding linking the Role to the ServiceAccount
	•	Wrong service account in pod spec → fix serviceAccountName in the Deployment
	•	RoleBinding in wrong namespace → move it to the namespace where the SA operates
	•	ClusterRole needed → if the resource is cluster-scoped, use ClusterRole + ClusterRoleBinding

Fix commands:

	# Fix in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Or create/fix imperatively
	kubectl create role <role> -n <ns> --verb=<verb> --resource=<resource>
	kubectl create rolebinding <binding> -n <ns> --role=<role> --serviceaccount=<ns>:<sa>
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/serviceAccountName","value":"<correct-sa>"}]'

Verification:

	kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa> -n <ns>    # should return yes
	kubectl logs <pod> -n <ns>    # no Forbidden errors

Docs: Using RBAC Authorization, Service Accounts.

---

Fix: Scheduling / node placement

What it usually means: The pod can't be placed on any node — insufficient resources, unmet node affinity, or unmatched tolerations.

First commands:

	kubectl describe pod <pod> -n <ns>          # Events: scheduling reason
	kubectl describe node                        # Allocatable, Conditions, Taints

Likely fixes:
	•	Insufficient CPU or memory → reduce resource requests, or free capacity on nodes
	•	Taint with no matching toleration → add the toleration to the pod spec, or remove the taint
	•	Node affinity/selector doesn't match any node → fix the affinity rules or label the node
	•	Multiple constraints compounding → check all of nodeSelector, affinity, tolerations, and resource requests together

Fix commands:

	# Fix resource requests, nodeSelector, or affinity in the manifest and re-apply (preferred in a repo-based interview)
	vi <manifest-file>
	kubectl apply -f <manifest-file> -n <ns>

	# Node-level fixes (these can't be done via app manifests)
	kubectl label node <node> <key>=<value>
	kubectl taint node <node> <key>:<effect>-

	# Or patch deployment imperatively
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"<value>"}]'
	kubectl patch deploy <deploy> -n <ns> --type=json \
	  -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'

Verification:

	kubectl get pods -n <ns>    # should transition from Pending to Running
	kubectl describe pod <pod> -n <ns>    # Events show successful scheduling

Docs: Assigning Pods to Nodes, Taints and Tolerations, Resource Management for Pods and Containers.

---

Fix: PVC / storage binding

What it usually means: A PersistentVolumeClaim can't bind to a volume — missing StorageClass, provisioner not running, access mode mismatch, or topology constraint.

First commands:

	kubectl get pvc -n <ns>
	kubectl describe pvc <pvc> -n <ns>          # Events: why it can't bind
	kubectl get storageclass
	kubectl get pv                               # is there a matching PV?

Likely fixes:
	•	StorageClass doesn't exist → create it, or fix the storageClassName in the PVC
	•	Provisioner not running → check the provisioner pods (e.g. in kube-system or a storage namespace)
	•	Access mode mismatch → PVC requests ReadWriteMany but the provisioner only supports ReadWriteOnce
	•	Capacity mismatch → PVC requests more than any available PV offers
	•	Topology constraint → volumeBindingMode is WaitForFirstConsumer and no node matches both the pod's scheduling constraints and the volume's topology. Check node labels and zone/region affinity
	•	Static PV not matching → check that the PV's capacity, access modes, and storageClassName match the PVC's requirements

Fix commands:

	# Fix storageClassName in PVC (delete and recreate — PVC spec is mostly immutable)
	kubectl delete pvc <pvc> -n <ns>
	vi <pvc-manifest>
	kubectl apply -f <pvc-manifest> -n <ns>

	# Fix access mode or capacity (also requires delete and recreate)
	kubectl delete pvc <pvc> -n <ns>
	vi <pvc-manifest>
	kubectl apply -f <pvc-manifest> -n <ns>

	# Check available StorageClasses
	kubectl get storageclass

Verification:

	kubectl get pvc -n <ns>    # should show Bound
	kubectl get pods -n <ns>    # pod should transition from Pending to Running

Docs: Persistent Volumes, Storage Classes, Debug Pods.

---

Fix sections added:
	1.	Image pull failure
	2.	Config / Secret / volume reference
	3.	Config / Secret values
	4.	Probe configuration
	5.	App startup / entrypoint failure
	6.	Init container failure
	7.	Memory limits (OOMKilled)
	8.	Service selector and port mapping
	9.	Ingress routing
	10.	DNS / service discovery
	11.	Dependency connectivity
	12.	NetworkPolicy rules
	13.	RBAC / service account
	14.	Scheduling / node placement
	15.	PVC / storage binding
