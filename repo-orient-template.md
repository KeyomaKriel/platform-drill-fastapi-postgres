Repo orientation mismatch-hunting template

Use this as a working sheet while you open files.
Goal: extract only what matters for debugging, and explicitly spot mismatches.

⸻

Repo Orientation Worksheet

0. Basic context
	•	Repo name:
	•	Branch:
	•	Namespace:
	•	App/workload name:
	•	Date / drill name:

⸻

1. App shape

What this app is
	•	Language/runtime:
	•	Framework:
	•	Main app file / entrypoint file:
	•	Other app components in repo:
	•	What the app appears to do:
	•	Known endpoints/routes:
	•	Health endpoints:
	•	Background jobs / workers / cron components:

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Mismatch / suspicion notes
	•	Missing app entrypoint?
	•	Routes unclear?
	•	Health path unclear?
	•	More than one workload/component and not yet sure which matters?

⸻

2. Start

How the app/container starts
	•	Dockerfile path:
	•	Base image:
	•	WORKDIR:
	•	EXPOSE:
	•	ENTRYPOINT:
	•	CMD:
	•	Deployment command: override:
	•	Deployment args: override:
	•	Init containers:
	•	Startup dependencies visible in code:
	•	Does app fail hard on missing dependency, or retry?
	•	Does app create tables / run migrations / seed data on startup?

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Start mismatch checks
	•	Dockerfile EXPOSE vs app listening port:
	•	Dockerfile CMD/ENTRYPOINT vs Deployment command/args:
	•	App startup command vs actual file paths:
	•	Init container expected dependency vs actual service name:
	•	Startup requires dependency to be up, but repo suggests dependency may not yet be ready:
	•	Image/tag style suggests local image loading (imagePullPolicy: Never, :local)?
	•	Anything that could cause:
	•	ImagePullBackOff
	•	CreateContainerError
	•	CreateContainerConfigError
	•	startup crash

Mismatch / suspicion notes
	•	Port mismatch?
	•	Bad command/args risk?
	•	Missing startup dependency?
	•	Init container risk?
	•	Local image workflow risk?

⸻

3. Stay up

How health is judged
	•	Readiness probe path:
	•	Readiness probe port:
	•	Readiness timing:
	•	Liveness probe path:
	•	Liveness probe port:
	•	Liveness timing:
	•	Startup probe path:
	•	Startup probe port:
	•	Startup probe timing:
	•	What does the app need to be “healthy”?
	•	What could make it run but not be Ready?
	•	What could make liveness restart it?

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Stay up mismatch checks
	•	Probe path vs actual app route:
	•	Probe port vs actual container port:
	•	Readiness path returns 200?
	•	Liveness path appropriate, or too strict?
	•	Startup probe missing for slow-starting app?
	•	Probe timings too aggressive for startup behavior?
	•	App depends on DB/cache/service before health passes?

Mismatch / suspicion notes
	•	Wrong path?
	•	Wrong port?
	•	Timing too aggressive?
	•	Health tied to dependency that may not be ready?
	•	CrashLoop / 0/1 Ready risk?

⸻

4. Receive Traffic

How traffic reaches the app
	•	Deployment name:
	•	Pod template labels:
	•	Service name:
	•	Service type:
	•	Service selector:
	•	Service port:
	•	Service targetPort:
	•	Container port:
	•	Ingress name:
	•	ingressClassName:
	•	Ingress host(s):
	•	Ingress path(s):
	•	Ingress backend service:
	•	Ingress backend port:
	•	Any external URL / expected curl path:

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Receive Traffic mismatch checks
	•	Service selector vs pod labels:
	•	Service targetPort vs container port:
	•	Service port vs Ingress backend port:
	•	Ingress backend service name vs actual Service name:
	•	Ingress path/host vs expected routes:
	•	Ingress exists but no obvious ingress controller class?
	•	Multiple Services — not sure which one fronts the app?
	•	Pod is only internally reachable and no Ingress present?

Mismatch / suspicion notes
	•	Selector mismatch risk?
	•	Port mismatch risk?
	•	Ingress backend mismatch risk?
	•	Host/path mismatch risk?
	•	Missing external exposure?

⸻

5. Reach Dependencies

What the app needs to talk to
	•	Required env vars:
	•	Optional env vars:
	•	ConfigMap(s):
	•	Secret(s):
	•	Mounted config files:
	•	Database dependency:
	•	Cache dependency:
	•	External API dependency:
	•	Internal service dependency:
	•	Expected service hostnames:
	•	Expected ports:
	•	Credentials source:
	•	Service account:
	•	Any obvious RBAC needs:
	•	Any obvious NetworkPolicy manifests:

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Reach Dependencies mismatch checks
	•	Env var names in code vs env vars in Deployment:
	•	ConfigMap/Secret names in Deployment vs actual manifest names:
	•	Secret keys referenced vs actual keys present:
	•	DB host value vs actual Service name:
	•	Internal service hostnames vs actual Service names:
	•	Port values vs actual dependency ports:
	•	Credentials source present?
	•	ServiceAccount named but RBAC manifests absent?
	•	NetworkPolicy present that may block DB/DNS/internal traffic?
	•	Namespace assumptions visible in hostnames?

Mismatch / suspicion notes
	•	Missing env var?
	•	Wrong hostname?
	•	Wrong port?
	•	Wrong secret/config reference?
	•	Permission risk?
	•	DNS/service discovery risk?
	•	Dependency auth risk?

⸻

6. Deploy path

How repo changes become cluster changes
	•	Deploy mechanism:
	•	raw manifests / Helm / Kustomize / script / Makefile / justfile / CI
	•	Build command:
	•	Image build target:
	•	Image tag convention:
	•	Registry:
	•	Image pull policy:
	•	Apply command:
	•	Any local cluster image-loading step:
	•	Any rollout/restart step implied:

Evidence
	•	File(s) checked:
	•	Key lines / findings:

Deploy path mismatch checks
	•	Raw manifests present but actual deploy done via script?
	•	Helm values likely override template assumptions?
	•	imagePullPolicy: Never but no local load step found?
	•	Local image tag in manifests but no build/load instructions?
	•	Repo suggests one deploy path, cluster behavior suggests another?
	•	Fix will require image rebuild, but you are only editing manifests?

Mismatch / suspicion notes
	•	Unclear deploy path?
	•	Local image trap?
	•	Helm/Kustomize indirection risk?
	•	Easy to make a fix that won’t actually take effect?

⸻

7. Quick live checks

Run these after the repo scan.

Commands run

kubectl get pods -n <ns>
kubectl get endpoints -n <ns>
curl -i localhost/
curl -i -H "Host: <host>" localhost/

Results
	•	Pods:
	•	Ready counts:
	•	Restart counts:
	•	Endpoints:
	•	Ingress curl result:
	•	Service curl / port-forward result:
	•	Any error text:

Live-check mismatch checks
	•	Pods unhealthy even though manifests look fine?
	•	Endpoints empty despite Service existing?
	•	Service works but Ingress fails?
	•	Pod running but not Ready?
	•	Curl path used does not match actual route/host rules?
	•	Cluster reality differs from repo assumptions?

Strongest signal so far
	•	Symptom:
	•	Likely bucket:
	•	Closest object:
	•	Fastest next command:

⸻

8. Expected vs actual summary

This is the most important section.

Start
	•	Expected:
	•	Actual:
	•	Match / mismatch:
	•	Confidence:

Stay up
	•	Expected:
	•	Actual:
	•	Match / mismatch:
	•	Confidence:

Receive Traffic
	•	Expected:
	•	Actual:
	•	Match / mismatch:
	•	Confidence:

Reach Dependencies
	•	Expected:
	•	Actual:
	•	Match / mismatch:
	•	Confidence:

⸻

9. Priority mismatch list

List only the most likely high-value issues.

Likely mismatch 1
	•	What:
	•	Evidence:
	•	Bucket:
	•	Closest object:
	•	Next command:

Likely mismatch 2
	•	What:
	•	Evidence:
	•	Bucket:
	•	Closest object:
	•	Next command:

Likely mismatch 3
	•	What:
	•	Evidence:
	•	Bucket:
	•	Closest object:
	•	Next command:

⸻

10. Spoken orientation summary

Use this to speak back your understanding before you start fixing.

30-second summary
	•	What the app is:
	•	How it starts:
	•	How it is exposed:
	•	What it depends on:
	•	Strongest signal / likely problem area:

1-minute summary
	•	Repo shape:
	•	Startup path:
	•	Health path:
	•	Traffic path:
	•	Dependency path:
	•	Most likely mismatch:
	•	First troubleshooting move:

⸻

Ultra-short version for real interview use

If you need a very compressed version, use this:

Repo mismatch mini-sheet

App
	•	Main file:
	•	Endpoints:
	•	Health path:

Start
	•	Dockerfile CMD/ENTRYPOINT:
	•	Container port:
	•	Init containers:
	•	Startup dependency risk:
	•	Mismatch:

Stay up
	•	Readiness:
	•	Liveness:
	•	Startup probe:
	•	Mismatch:

Receive Traffic
	•	Pod labels:
	•	Service selector:
	•	Service port → targetPort:
	•	Ingress host/path/backend:
	•	Mismatch:

Reach Dependencies
	•	Env vars:
	•	ConfigMap/Secret refs:
	•	DB/internal service hostnames:
	•	RBAC / NetworkPolicy:
	•	Mismatch:

Live checks
	•	Pods:
	•	Endpoints:
	•	Curl:
	•	Strongest signal:
	•	Next command:

⸻