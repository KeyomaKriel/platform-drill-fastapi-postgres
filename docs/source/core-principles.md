1. The interview context and scope

This is a 60-minute hands-on Platform Engineer interview built around a repo-based practical task in a prepared environment. The candidate is expected to use the repo and the running Kubernetes environment together. The interview is testing whether you can:
	•	orient quickly in an unfamiliar repo
	•	understand what the app does and how it is deployed
	•	inspect the live Kubernetes runtime
	•	debug a realistic issue or make a small realistic change
	•	verify end-to-end
	•	explain your reasoning clearly as you go.  ￼

2. The core set of principles to memorize

A. Core interview principles
	•	Start from the repo and the running system together.
	•	Do not guess the root cause.
	•	Build a quick mental model before acting.
	•	Use a consistent troubleshooting sequence.
	•	Choose the right entry mode: broad triage vs fast path.
	•	Distinguish symptom from root cause.
	•	Be hypothesis-driven.
	•	Apply the smallest justified fix.
	•	Verify end-to-end.
	•	Narrate clearly as you go.

B. Core troubleshooting sequence

The default sequence should be something like:
	1.	repo-first orientation
	2.	confirm cluster context/namespace
	3.	identify workload / full picture
	4.	check pod state
	5.	describe pod
	6.	check logs
	7.	if pod is healthy, test pod reachability
	8.	test service and endpoints
	9.	test ingress / external path
	10.	branch into the relevant root-cause domain
	11.	apply the smallest justified fix
	12.	verify end-to-end.

C. Relevant theory you should know
	•	how app code, env vars, Dockerfile, manifests, and runtime fit together
	•	service path: app process → pod port → service → ingress
	•	what probes do and how they fail
	•	how ConfigMaps/Secrets/env injection work
	•	how selectors/endpoints work
	•	what DNS/service discovery means in-cluster
	•	what NetworkPolicies actually block
	•	the distinction between pod symptom and root-cause domain
	•	deploy path awareness: build, load, apply, restart, verify.



