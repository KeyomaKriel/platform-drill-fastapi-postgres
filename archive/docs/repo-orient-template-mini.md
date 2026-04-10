Repo mismatch mini-sheet

App
	•	Main file:
	•	Endpoints:
	•	Health path:
	•	Main mismatch to watch: health path unclear or does not obviously match probes

Start
	•	Dockerfile CMD/ENTRYPOINT:
	•	Container port:
	•	Init containers:
	•	Startup dependency risk:
	•	Main mismatches to watch:
	•	command/args override does not match how app should start
	•	container/app port does not line up

Stay up
	•	Readiness:
	•	Liveness:
	•	Startup probe:
	•	Main mismatches to watch:
	•	probe path does not exist
	•	probe port does not match container port
	•	timing obviously too aggressive

Receive Traffic
	•	Pod labels:
	•	Service selector:
	•	Service port → targetPort:
	•	Ingress host/path/backend:
	•	Main mismatches to watch:
	•	selector does not match pod labels
	•	targetPort does not match container port
	•	ingress backend name/port does not match Service

Reach Dependencies
	•	Env vars:
	•	ConfigMap/Secret refs:
	•	DB/internal service hostnames:
	•	RBAC / NetworkPolicy:
	•	Main mismatches to watch:
	•	env/config object names do not match references
	•	dependency hostname does not match actual Service name
	•	obvious missing credential/config source

Live checks
	•	Pods:
	•	Endpoints:
	•	Curl:
	•	Strongest signal:
	•	Next command:

Why this is better

Because “Mismatch:” by itself is too open-ended. Under stress, that can make you hesitate.

If the main mismatch types are already baked in, the sheet becomes much more useful:
	•	you extract the fact
	•	you compare it against the likely mismatch
	•	you either see a problem or move on
