
Update CLAUDE.md with a small targeted refinement focused only on debugging alignment inside Phase 3.

Do not do a broad rewrite of the file. Do not rewrite Phase 1 or Phase 2. Do not do the full Phase 4 rewrite yet. Only make the smallest non-Phase-3 edits required for consistency.

Goal

Align CLAUDE.md’s debugging model more closely with the strongest human-facing concepts from playbook.md, specifically:
	•	Entry Modes
	•	Full Triage
	•	Fast Path
	•	Interview Runtime Flow
	•	orient
	•	identify workload
	•	check pod state
	•	describe pod
	•	check logs
	•	test pod reachability
	•	test service/endpoints
	•	test ingress/external path
	•	then branch into the right debugging bucket

This is only about the debugging scope inside CLAUDE.md.

Why this change is needed

CLAUDE.md now has the better top-level debugging bucket taxonomy and the better repo-based interview framing.

But playbook.md still has stronger human debugging start logic:
	•	when to do broad triage vs a narrower fast path
	•	the practical step-by-step runtime loop a candidate should follow live

I want CLAUDE.md to evaluate and coach against that same debugging flow, so the drill engine and the human playbook are not teaching two different models.

What to change

1. Add debugging Entry Modes inside Phase 3

Within the single-fault debugging part of Phase 3, add a short operational subsection for Entry Modes.

It should define:

Full Triage
Use when:
	•	scope is ambiguous
	•	multiple things may be broken
	•	the user does not yet know which workload or layer is at fault

It should make clear that in this mode the user should orient broadly before committing to a failure bucket.

Fast Path
Use when:
	•	the app/workload is already known
	•	the symptom is already reasonably clear
	•	the cause is still unknown

It should make clear that in this mode the user can go straight to the likely workload and then proceed layer-by-layer.

Keep this practical and concise. Do not turn it into a long essay.

2. Add / align an Interview Runtime Flow for debugging inside Phase 3

Within the single-fault debugging part of Phase 3, add or revise the debugging flow so Claude evaluates against a clear live-use sequence like this:
	1.	orient
	2.	identify workload
	3.	check pod state
	4.	describe pod
	5.	check logs
	6.	if pod is healthy, test pod reachability
	7.	test service/endpoints
	8.	test ingress/external path
	9.	if it is not a path problem, branch into the right debugging bucket
	10.	apply the smallest justified fix
	11.	verify end-to-end

Important:
	•	keep this aligned with the repo-based interview model
	•	allow repo orientation first or alongside cluster orientation
	•	do not make it purely Kubernetes-first
	•	but do make the runtime flow concrete and operational

3. Keep the current better top-level debugging bucket taxonomy

Do not revert to the older debugging domains from playbook.md.

Keep the current top-level failure buckets already present in CLAUDE.md, such as:
	•	startup / crash
	•	image pull / container creation
	•	probe
	•	config / Secret / env
	•	service routing / port / endpoint
	•	DNS / service discovery / namespace
	•	resource / scheduling / storage
	•	ingress / external routing
	•	NetworkPolicy / traffic restriction
	•	RBAC / service account / permission
	•	application-level dependency / runtime

The alignment should be:
	•	runtime flow and entry modes from the human playbook
	•	top-level bucket taxonomy from the current CLAUDE.md

4. Improve Phase 3 evaluation/coaching alignment for debugging

Make sure the debugging evaluation model in Phase 3 now reflects:
	•	whether the user chose the right entry mode
	•	whether they used a sensible runtime flow
	•	whether they oriented broadly when needed
	•	whether they narrowed quickly when the signal was clear

Do not massively expand the section; just make the evaluation criteria and debugging flow more aligned to the new model.

5. Preserve the repo-first interview framing

The updated debugging flow must still reflect that this is a repo-based practical interview.

So:
	•	repo orientation may happen before or alongside cluster checks
	•	the runtime flow should not imply that debugging starts only at kubectl get pods
	•	Claude should still reward candidates who quickly understand the repo/deploy path before or during debugging

6. Keep this a targeted update

This is not the Phase 4 rewrite.

This is not a full rewrite of Phase 3.

This is just to bring the debugging part of CLAUDE.md into better alignment with:
	•	better entry-mode logic
	•	better live runtime flow

Constraints
	•	Focus on debugging scope only
	•	Keep the overall structure of CLAUDE.md
	•	Keep the tone practical and operational
	•	Do not bloat the document
	•	Do not replace the current top-level bucket taxonomy
	•	Do not rewrite unrelated sections

Output
	•	Update CLAUDE.md in place
	•	Briefly summarize:
	•	where you added or revised Entry Modes
	•	where you added or revised the debugging runtime flow
	•	any tiny non-Phase-3 edits made only for consistency
