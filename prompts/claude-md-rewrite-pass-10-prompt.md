Update playbook.md with a targeted improvement to the Repo-First Orientation section.

Do not do a broad rewrite of the whole file.

Goal

The current Repo-First Orientation section is directionally right, but it is still too high-level for actual learning and interview practice.

I need it to be much more explicit and practical.

It should help me answer questions like:
	•	where do I look if the README does not tell me enough?
	•	what exactly am I looking for in the app code, config, Dockerfile, and manifests?
	•	what does each thing I find actually tell me?
	•	how do I identify the deploy path?
	•	what is realistically likely to be present in an interview repo?

What to improve

Rewrite or substantially expand the Repo-First Orientation section so it becomes a practical handbook section for interview prep.

It should clearly explain:

1. What “repo-first orientation” is actually for

Make it explicit that the goal is to build a quick mental model of:
	•	what the app does
	•	what it depends on
	•	how it is supposed to run in the container
	•	how it is supposed to run in Kubernetes
	•	how repo changes become running changes

2. Where to look if the README is incomplete

Do not imply the README will always contain everything.

Explain a practical search order such as:
	•	README / docs
	•	app entrypoint / main app file
	•	config/settings/env loading
	•	dependency files
	•	Dockerfile
	•	Kubernetes manifests / Helm / Kustomize
	•	helper scripts / Makefile / justfile / CI clues

3. What to look for in each place, and what it tells you

This is the most important improvement.

For each source of truth, explain:
	•	what I am looking for
	•	what that tells me operationally
	•	why it matters in troubleshooting or interview reasoning

Especially cover:
	•	app entrypoint / routes / startup logic
	•	env vars and dependency configuration
	•	Dockerfile (base image, EXPOSE, CMD/ENTRYPOINT, COPY, etc.)
	•	Deployment / Service / Ingress / ConfigMap / Secret / NetworkPolicy
	•	Helm / Kustomize indicators
	•	helper scripts or deploy commands

4. Make “identify the deploy path” much more explicit

Right now this idea is too vague.

Explain clearly:
	•	where to look for deploy-path clues
	•	how to tell whether the repo uses raw manifests, Helm, Kustomize, scripts, or pipeline-driven deployment
	•	what that tells me about how to apply a fix properly
	•	why this matters before making changes

5. Keep it grounded in realistic interview conditions

Explain that in a real interview:
	•	the repo may be only partly documented
	•	the README may be incomplete
	•	the candidate often has to infer the system from code + manifests + Dockerfile + config
	•	the goal is a fast, practical mental model, not exhaustive reading

6. Make it concrete and practical

This section should still read like part of the handbook, not like an essay.

Use:
	•	short subsections
	•	concise bullets where useful
	•	practical wording
	•	concrete examples where appropriate

7. Keep app-specific assumptions under control

If you mention things like /, /health, etc.:
	•	frame them as common examples
	•	do not imply they always exist
	•	where useful, say “or a known app path from the scenario”

Constraints
	•	Edit only the Repo-First Orientation section and make only tiny surrounding edits if needed for coherence
	•	Do not do a broad rewrite of the rest of the handbook
	•	Keep the handbook tone practical and study-friendly
	•	Do not make the section generic fluff
	•	Do not make it excessively long, but do make it much more explicit than it is now

Output

Update playbook.md in place.

After editing, provide a short summary of:
	•	how the section is now more explicit
	•	what new practical guidance was added
	•	any small surrounding edits made for coherence