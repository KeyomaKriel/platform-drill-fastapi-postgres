
Update CLAUDE.md with a targeted rewrite of Phase 3 only.

Do not do a broad rewrite of the file. Do not significantly rewrite Phase 1 or Phase 2. Do not fully rewrite Phase 4 in this pass except for tiny consistency edits if absolutely necessary.

Goal

Phase 3 currently still carries too much of the old debugging-only model.

Rewrite Phase 3 so it becomes a proper task-type-aware interview simulation and evaluation engine for the drill system.

The task model already exists in Phase 2:
	•	healthy orientation
	•	single-fault debugging
	•	small implementation/change
	•	verification/trade-off

Phase 3 should now reflect that explicitly.

Main objectives

1. Make Phase 3 explicitly task-type aware

Rewrite Phase 3 so it clearly explains how the simulation and evaluation should work for each task type:
	•	healthy orientation
	•	single-fault debugging
	•	small implementation/change
	•	verification/trade-off

Do not leave the section feeling like debugging is the default and everything else is a minor variation.

2. Keep debugging as the deepest path, but contain it properly

The existing debugging machinery is still useful:
	•	hidden fault injection
	•	triage methodology
	•	signal failure domains 
	•	bucket-specific diagnostics
	•	playbook update logic

Keep these, but clearly position them as the detailed path for the single-fault debugging task type, not as the implicit operating model for all drills.

3. Replace the current top-level debugging failure domains with a better failure domainmodel

The current failure-domain list is too uneven and overlapping as a top-level taxonomy.

Use this as the new top-level failure domain model for debugging drills:
	•	Startup / crash failure
	•	Image pull / container creation failure
	•	Probe failure
	•	Config / Secret / env failure
	•	Service routing / port / endpoint failure
	•	DNS / service discovery / namespace failure
	•	Resource / scheduling / storage failure
	•	Ingress / external routing failure
	•	NetworkPolicy / traffic restriction failure
	•	RBAC / service account / permission failure
	•	Application-level dependency / runtime failure

Important:
	•	These should be the top-level practice/debugging domains
	•	The more specific current cases can still be preserved as subcases/examples/signals under these failure domains 
	•	The goal is a cleaner triage-oriented taxonomy, not losing useful detail

4. Define what good performance looks like for each task type

Rewrite the evaluation model so it is clearer what Phase 3 should evaluate for each task type.

For example:
	•	Healthy orientation
	•	did the user orient in the repo first
	•	did they identify app purpose, deploy path, manifests, verification path
	•	did they verify end-to-end without random wandering
	•	Single-fault debugging
	•	did they orient first
	•	read signals well
	•	form and test hypotheses
	•	choose the right bucket
	•	apply the smallest justified fix
	•	verify properly
	•	Small implementation/change
	•	did they find the right place to change
	•	make a minimal correct implementation
	•	understand build/deploy path
	•	rebuild/redeploy correctly
	•	verify end-to-end
	•	Verification/trade-off
	•	did they inspect the repo/runtime before answering
	•	reason from evidence, not generic best practices
	•	explain trade-offs clearly and specifically

Make this operational, not vague.

5. Improve the Phase 3 interaction loop

The interaction loop should clearly support all task types.

Rewrite it so Claude Code knows:
	•	how to present the task
	•	how to stay silent while the user works
	•	how to evaluate based on task type
	•	what to verify after the user finishes
	•	what to reveal afterward
	•	what feedback to write
	•	how to clean up and restore baseline

6. Tighten feedback output

Make the feedback framework more task-type-aware and more useful.

It should still include shared criteria like:
	•	orientation
	•	intentional actions/commands
	•	hypothesis-driven behaviour
	•	smallest justified fix
	•	end-to-end verification
	•	communication

But it should also make clear which criteria apply most strongly to which task type.

7. Fix known inconsistencies while rewriting Phase 3

Please fix these specific issues during the Phase 3 rewrite:
	•	The feedback filename pattern currently says scenario-<N>-<task-type-slug>.md but an example uses a failure-domain slug like networking-service-routing. Make the naming rule and examples consistent.
	•	The fallback path for “just break something” currently introduces a second log model at ./drill-session.log. Simplify or clarify this if possible while keeping the system operational.
	•	Make sure Phase 3 path references are fully consistent with the current root-relative filesystem model.

8. Keep the good parts

Preserve the strongest useful pieces from the current Phase 3 where they still fit:
	•	hidden fault injection for debugging tasks
	•	triage methodology
	•	repo-first orientation
	•	feedback files
	•	playbook update logic
	•	strict interviewer/silent-evaluator behaviour

Constraints
	•	Rewrite Phase 3 only
	•	Do not perform a big rewrite of other phases
	•	Keep the file’s overall architecture intact
	•	Keep the tone practical, strict, and operational
	•	Do not make the new Phase 3 abstract
	•	Make it feel like a real operating manual for running drills

Output
	•	Update CLAUDE.md in place
	•	Rewrite Phase 3 into a clearer task-type-aware simulation/evaluation section
	•	Briefly summarize:
	•	what changed in Phase 3
	•	any tiny non-Phase-3 edits made only for consistency

