Repo-First Orientation update to be made in playbook.md

It should be rewritten from a file-by-file walkthrough into an extraction worksheet workflow.

Repo-First Orientation = fill in the worksheet, not “read these files”

That means the section should tell you:
	•	use the template as the working artifact
	•	open files only to fill in template fields
	•	explicitly look for mismatches as you go
	•	stop orientation as soon as a strong signal appears

The main change

Change the section from:

“Step 1, Step 2, Step 3…”

to:

“Fill in these worksheet sections in this order…”

The order should follow the template:
	1.	App shape
	2.	Start
	3.	Stay up
	4.	Receive Traffic
	5.	Reach Dependencies
	6.	Deploy path
	7.	Quick live checks
	8.	Expected vs actual / strongest signal

That is the right mental order.

What the section should say at the top

Add a short framing paragraph like:

During repo orientation, do not try to understand the whole repo or remember everything. Use the repo-orientation worksheet as a working artifact. As you open files, extract only the facts needed to fill in the template and note any mismatches. The goal is to build an expected-vs-actual model quickly, not to read every file.

That is the key shift.

How the subsections should be structured

Instead of “Step 2 — App entrypoint (almost always open this)”, it should be more like:

Fill in: App shape

Goal:
	•	identify the app, main file, endpoints, health routes, components

Look in:
	•	repo structure
	•	README
	•	main app file

Write down:
	•	language/runtime
	•	main file
	•	endpoints
	•	health path
	•	what the app appears to do

Mismatch questions:
	•	are the routes clear?
	•	is the health path clear?
	•	are there multiple components and I do not yet know which one matters?

That same pattern should repeat for each template section.

The exact pattern to use for each section:

Section name

Goal
What you are trying to learn.

Look in
Which files usually contain the answer.

Write down
Which template fields to fill in.

Mismatch checks
What to compare and what kinds of mismatch to look for.

Narrate
A short interview-safe line.

How each current step maps to the template

1. App shape

This should absorb the current:
	•	repo structure step
	•	app entrypoint step
	•	maybe README mention

It should tell you to fill in:
	•	language/runtime
	•	framework
	•	main file
	•	endpoints
	•	health endpoints
	•	components/services

2. Start

This should absorb the current:
	•	Dockerfile step
	•	startup logic from main app file
	•	Deployment command/args/image/init containers

It should tell you to fill in:
	•	Dockerfile path
	•	EXPOSE
	•	ENTRYPOINT/CMD
	•	Deployment command/args
	•	init containers
	•	startup dependencies
	•	startup failure behavior

And compare:
	•	app listening port vs Dockerfile EXPOSE
	•	Dockerfile CMD/ENTRYPOINT vs Deployment overrides
	•	init container expected service vs real service name

3. Stay up

This should be pulled out more explicitly than it currently is.

Right now probes are buried mostly in the Deployment step.  ￼

Instead, this section should clearly tell you to fill in:
	•	readiness probe path/port/timing
	•	liveness probe path/port/timing
	•	startup probe path/port/timing
	•	what healthy means for this app

And compare:
	•	probe path vs actual app route
	•	probe port vs actual port
	•	probe timing vs startup behavior

4. Receive Traffic

This should absorb the current:
	•	Service step
	•	Ingress step

It should tell you to fill in:
	•	Deployment name
	•	pod labels
	•	Service name/type
	•	selector
	•	port → targetPort
	•	Ingress host/path/backend/class

And compare:
	•	Service selector vs pod labels
	•	targetPort vs container port
	•	Ingress backend service name vs actual Service
	•	Ingress backend port vs Service port

5. Reach Dependencies

This should absorb the current:
	•	ConfigMap/Secret step
	•	env var mention from app entrypoint
	•	service account/RBAC/policy mentions if visible

It should tell you to fill in:
	•	required env vars
	•	ConfigMaps/Secrets
	•	DB/internal service names
	•	credentials source
	•	service account
	•	obvious RBAC or NetworkPolicy files

And compare:
	•	env var names in code vs Deployment
	•	referenced ConfigMap/Secret names vs actual manifests
	•	hostnames vs actual Service names
	•	ports vs actual dependency ports

6. Deploy path

This part is already pretty good and should remain, but it should be reframed as “fill in the deploy path section of the worksheet.”  ￼

7. Quick live checks

This should remain, but the wording should be more template-based:
	•	record pods result
	•	record endpoints result
	•	record curl result
	•	write down strongest signal so far

The new version should explicitly say:

You do not need to read files in a strict order. Jump to whichever file fills the next missing field in the worksheet.