

You need to answer only five things, fast:
	1.	What kind of app is this?
	2.	What process starts it?
	3.	What port does it listen on?
	4.	What paths/endpoints matter?
	5.	Which manifests wire traffic and config into it?

What to look for first

Run:

pwd
ls
tree -L 2

Then look for these files:
	•	Dockerfile
	•	requirements.txt, pyproject.toml, package.json, or go.mod
	•	manage.py
	•	app code folder
	•	manifests/, k8s/, or yaml files

How to recognize the app quickly

Django

You are probably looking at Django if you see:
	•	manage.py
	•	a project package like config/ or similar
	•	app folders with files like:
	•	models.py
	•	views.py
	•	urls.py
	•	serializers.py
	•	migrations/

What to say:

“This looks like a Django app. manage.py is the big signal. I’d expect settings in the project package, routes in urls.py, and request handlers in views.py.”

Simple Python app

You are probably looking at a simpler Python app if you see:
	•	app.py or main.py
	•	requirements.txt
	•	maybe flask, fastapi, or similar in dependencies
	•	fewer nested framework files

What to say:

“This looks like a simpler Python service rather than a larger framework app. I’d expect the routes and startup logic to be more concentrated in one or two files.”

Go app

You are probably looking at Go if you see:
	•	go.mod
	•	main.go
	•	maybe folders like cmd/, internal/, pkg/

What to say:

“This is a Go service. go.mod and main.go are the main signals. I’m going to check main.go for startup, routes, and the listening port.”

That is enough. Do not try to become good at Django in a few hours. Just learn these recognition signals.

What files matter most

Read in this order:

1. Dockerfile

You want:
	•	CMD or ENTRYPOINT
	•	port
	•	app start command

What to say:

“I’m checking what actually starts in the container and which port it expects to serve on, because that has to line up with probes and Service targetPort.”

2. App entrypoint / routing files

For Django:
	•	manage.py
	•	config/settings.py
	•	*/urls.py
	•	*/views.py

For Python:
	•	app.py or main.py

For Go:
	•	main.go

You want:
	•	main routes
	•	health endpoint
	•	readiness endpoint
	•	DB env vars if obvious

What to say:

“I’m checking which paths the app really serves and whether health endpoints exist, because probe path mismatches are a common failure.”

3. Deployment manifest

You want:
	•	image
	•	command/args override
	•	env/envFrom
	•	probes
	•	container port
	•	init containers

What to say:

“Now I’m checking how Kubernetes runs the app: image, config injection, probes, and whether the manifest overrides the Dockerfile startup.”

4. Service manifest

You want:
	•	selector
	•	port
	•	targetPort

What to say:

“This tells me how traffic reaches the pod. The selector must match pod labels, and targetPort must match the app’s listening port.”

5. Ingress manifest

You want:
	•	host
	•	path
	•	backend service name
	•	backend service port

What to say:

“This is the user-visible entry path. If the app is unreachable externally, this is one of the first contracts I’d verify.”

That is the real orientation flow.

What you should stop caring about for now

For the next few hours, do not spend time trying to master:
	•	Django models
	•	serializers
	•	business logic
	•	deep framework conventions
	•	every endpoint in the app
	•	every manifest field

That is not where you are likely to win or lose this interview.

What you should memorize instead

Fast framework recognition
	•	manage.py = Django
	•	go.mod / main.go = Go
	•	app.py / main.py + requirements.txt = likely simpler Python app

Fast runtime recognition
	•	Dockerfile CMD / ENTRYPOINT = what starts
	•	app code = what paths exist
	•	Deployment = how k8s runs it
	•	Service = how traffic reaches pods
	•	Ingress = how outside reaches Service

What to say during orientation

Use this exact script shape:

“I’m first mapping the repo so I know where the app code, container config, and Kubernetes manifests live.”

“This looks like a Django app / Python service / Go service because of these files.”

“I’m checking the Dockerfile to confirm the startup command and app port.”

“Now I’m checking the app routes and health endpoints so I know what the probes and traffic path should target.”

“Now I’m checking the Deployment, Service, and Ingress to verify the startup, config, and traffic contracts.”

That is enough narration. Keep it plain.

What the HTML should really do better

Your HTML should not be organized around abstract buckets first. That is part of why it is slowing you down. It should be organized around immediate recognition and action.

It should have:
	1.	a “spot the framework in 10 seconds” section
	2.	a “read these 5 files only” section
	3.	a “what to extract from each file” section
	4.	a “what to say out loud” line under each
	5.	a “don’t read deeper than this” warning

