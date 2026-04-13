

Create a new file named `repo-orient-visual-interview.html`.

Use `repo-orient-visual.html` as reference for visual quality only, not for structure. Keep the polished dark theme, card layout, and overall UI quality, but redesign the content for fast interview execution under pressure.

Goal:
This file must help me quickly:
1. recognize what kind of app/repo I am looking at
2. know exactly which files to open first
3. know exactly what to extract from each file
4. know exactly what to say while doing each step
5. know what minimal live checks to run after repo orientation

Critical rule:
Do NOT create a separate narration section.
Whenever I need to say something in the interview, that narration must appear directly inside the relevant step/card where I am working.

The page must be practical and action-oriented, not abstract.
Do NOT make the old “Shape / Start / Supply / Ship / Signals” buckets the primary structure. They may appear only as a small final summary section at the end.

Build the page around this structure:

1. Hero / purpose
- Clear title showing this is for interview repo orientation
- Subtext emphasizing speed, recognition, and saying the right things live

2. 10-second app recognition section
This must be prominent and easy to scan.
Show how to quickly recognize:
- Django
- simpler Python service
- Go service

For each one include:
- key files/folders that signal it
- where routes usually live
- where config/settings usually live
- likely startup/entry file
- narration blocks for each step that I need to say what I am doing and why.

Examples of signals to include:
- Django: `manage.py`, project package like `config/`, app folders with `views.py`, `urls.py`, `models.py`, `migrations/`
- simpler Python: `app.py` or `main.py`, `requirements.txt`, fewer framework folders
- Go: `go.mod`, `main.go`, maybe `cmd/`, `internal/`, `pkg/`

This section must explicitly help someone who does NOT already know Django or Go well.

3. Repo orientation commands section
Show only the minimal repo-shape commands:
- `pwd`
- `ls`
- `tree -L 2`
- or `find . -maxdepth 2 -type f | sort`

4. “Open these files in this order” section
This is the backbone of the page.
Use a numbered sequence with strong visual hierarchy.

The order:
1. `Dockerfile`
2. app entry / route / settings files
3. `Deployment`
4. `Service`
5. `Ingress`
6. `ConfigMap` / `Secret` only when needed

For each file/group create its own card.
Inside each card include these subsections:
- What to look for
- Why it matters
- What to say

Be concrete.

For Dockerfile:
- `CMD` / `ENTRYPOINT`
- exposed/listening port
- whether the manifest may override startup later

Embedded narration should be something like:
“I’m checking what actually starts in the container and which port it listens on, because that has to match probes and Service targetPort.”

For app code:
- main user-visible route(s)
- health/readiness path(s)
- obvious DB env vars
- startup behavior if obvious

Embedded narration should be something like:
“I’m checking which paths the app really serves and whether health endpoints exist, because probe-path mismatches are a common failure.”

For Deployment:
- image
- `command` / `args`
- `env` / `envFrom`
- probes
- `containerPort`
- init containers

Embedded narration should be something like:
“Now I’m checking how Kubernetes runs the app: image, startup override, config injection, probes, and init containers.”

For Service:
- selector
- port
- `targetPort`

Embedded narration should be something like:
“This tells me how traffic reaches the pod. The selector must match pod labels, and targetPort must match the app’s listening port.”

For Ingress:
- host
- path
- backend service name
- backend service port

Embedded narration should be something like:
“This is the user-visible entry path. If the app is unreachable externally, this is one of the first contracts I’d verify.”

For ConfigMap/Secret:
- env var names
- DB host / DB service naming contract
- only inspect when needed for config/dependency issues

Embedded narration should be something like:
“I’m checking whether the config names and values actually match what the app and dependent service expect.”

5. “After repo orientation: first live checks” section

Use only minimal live checks:
- `kubectl get pods -n <ns>`
- `kubectl get svc -n <ns>`
- `kubectl get ingress -n <ns>` if ingress exists
- `kubectl get endpoints -n <ns>` if checking service routing

6. Small final recap section
At the end, include a compact recap using:
- Shape
- Start
- Supply
- Ship
- Signals

Design requirements:
- Keep the polished, professional, dark visual design quality of the original
- Make it easier to scan under pressure
- Use strong sectioning, cards, badges, callouts, and code blocks
- Responsive/interactive layout
- Add a sticky mini table of contents only if it helps speed

Most important instruction:
At every step where I might need to speak in the interview, put the narration directly in that exact step.
Do not make me look elsewhere for what to say.