Repo mismatch mini-sheet

App
	•	Main file:
	•	Endpoints: /
	•	Health path: ?
	•	Main mismatch to watch: health path unclear or does not obviously match probes

Start
	•	Dockerfile CMD/ENTRYPOINT: FROM tiangolo/uvicorn-gunicorn-fastapi:python3.11
	•	Container port: 80
	•	Init containers:
	•	Startup dependency risk: COPY ./app/requirements.txt /app/
	COPY ./app /app
ENV PYTHONPATH=/app
	•	Main mismatches to watch:
	•	command/args override does not match how app should start
	•	container/app port does not line up

Stay up
	•	Readiness: none
	•	Liveness: none
	•	Startup probe: none
	•	Main mismatches to watch:
	•	probe path does not exist
	•	probe port does not match container port
	•	timing obviously too aggressive
	no explicit health checking; app may appear “up” even if not truly healthy

Receive Traffic
	•	Pod labels: k8app-backend
	•	Service selector: k8app-backend
	•	Service port → targetPort: 4000 - 80
	•	Ingress host/path/backend: 3000
	•	Main mismatches to watch:
	•	selector does not match pod labels
	•	targetPort does not match container port
	•	ingress backend name/port does not match Service

Reach Dependencies
	•	Env vars:
	  SERVER_NAME: server
  SERVER_HOST: http://localhost
  BACKEND_CORS_ORIGINS: '["http://localhost", "http://k8app.com", "http://k8app.com:80", "http://k8app.com:3001", "https://localhost", "https://k8app.com", "https://k8app.com:443", "https://k8app.com:4001"]'
  PROJECT_NAME: k8app
  POSTGRES_SERVER: postgres
  SECRET_KEY: 99d3b1f01aa639e4a76f4fc281fc834747a543720ba4c8a8648ba755aef9be7f
  # POSTGRES_PASSWORD: pass
  
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
