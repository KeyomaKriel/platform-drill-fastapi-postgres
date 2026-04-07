
Update CLAUDE.md with a targeted rewrite of Phase 4 only so it aligns with the current Phase 2 and the rewritten Phase 3.

Do not do a broad rewrite of the file. Do not significantly rewrite Phases 1–3. Only make tiny consistency edits outside Phase 4 if absolutely necessary.

Goal

Phase 4 should become a proper task-type-aware coaching mode that matches:
	•	the task model in Phase 2
	•	the simulation/evaluation model in Phase 3
	•	the updated debugging model in Phase 3, including:
	•	Entry Modes (Full Triage vs Fast Path)
	•	Interview Runtime Flow
	•	the current top-level debugging bucket taxonomy

Right now Phase 4 is still too biased toward debugging in a general way and does not fully reflect the newer task-type-aware structure.

Rewrite Phase 4 so it becomes a practical coaching engine for all task types:
	•	healthy orientation
	•	single-fault debugging
	•	small implementation/change
	•	verification/trade-off

Main objectives

1. Make coaching explicitly task-type aware

Rewrite Phase 4 so it clearly explains how coaching should differ by task type.

Healthy orientation
Coach the user to:
	•	inspect repo structure first
	•	identify app purpose, endpoints, dependencies, Dockerfile, manifests, and deploy path
	•	verify the system in a systematic way
	•	avoid random cluster poking before understanding the repo

Single-fault debugging
Coach the user through the updated debugging model:
	•	choose the right Entry Mode:
	•	Full Triage when scope is ambiguous
	•	Fast Path when app/workload and symptom are already reasonably clear
	•	use the Interview Runtime Flow:
	1.	orient
	2.	identify workload
	3.	check pod state
	4.	describe pod
	5.	check logs
	6.	test pod reachability
	7.	test service/endpoints
	8.	test ingress/external path
	9.	branch into the right debugging bucket
	10.	apply the smallest justified fix
	11.	verify end-to-end
	•	coach signal reading
	•	coach bucket selection
	•	coach hypothesis formation
	•	coach smallest justified fix
	•	coach end-to-end verification

Small implementation/change
Coach the user to:
	•	understand the repo and existing patterns first
	•	find the correct file/location to change
	•	make a minimal, consistent change
	•	understand the build/load/deploy path
	•	rebuild/redeploy correctly
	•	verify both the new behaviour and existing behaviour

Verification/trade-off
Coach the user to:
	•	gather evidence before answering
	•	inspect repo and runtime before giving opinions
	•	make specific observations
	•	reason from what they actually saw
	•	explain trade-offs clearly and concretely
	•	avoid generic best-practice talking points

2. Keep the structured coaching response format

The current coaching response shape is still good and should remain the default unless a tiny adjustment is clearly better:
	•	What I See
	•	Working Theory
	•	Say This Out Loud
	•	Next Step

Keep this structure, but make it work naturally across all task types, not just debugging.

3. Align debugging coaching with the updated Phase 3 model

For debugging tasks, Phase 4 should now explicitly align to the current Phase 3 model.

That means coaching should reflect:
	•	Entry Modes
	•	Interview Runtime Flow
	•	the current top-level debugging buckets:
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

Do not revert to the older playbook taxonomy.

4. Preserve the strongest existing coaching rules

Keep the good current principles where they still fit:
	•	don’t skip ahead
	•	frame as hypothesis, not conclusion
	•	keep “Say This Out Loud” natural and realistic
	•	work with partial output when necessary
	•	pick the strongest signal rather than chasing multiple paths
	•	keep coaching fast and usable under time pressure
	•	coach repo orientation first when appropriate

5. Make non-debugging coaching operational, not vague

This is one of the main goals.

Implementation/change and verification/trade-off tasks should now be just as operationally coachable as debugging tasks.

Do not leave them as general advice.

Make Phase 4 concretely useful when:
	•	the user is trying to understand where to make a code/config/manifests change
	•	the user is trying to reason about production-readiness, failure behaviour, or trade-offs from actual evidence
	•	the user is orienting in the repo for the first time

6. Keep terminology and path assumptions aligned

Phase 4 should use the same:
	•	task-type language
	•	debugging bucket language
	•	workspace/log path assumptions
	•	repo-first interview framing

as the rest of CLAUDE.md.

7. Keep it concise and usable

Do not overcomplicate Phase 4.

It should remain something Claude Code can actually follow during live practice.

The result should feel like a practical coaching companion to Phase 3, not a generic tutorial.

Constraints
	•	Rewrite Phase 4 only
	•	Do not do a broad rewrite of the rest of the file
	•	Keep the tone practical, direct, and operational
	•	Do not make it abstract, fluffy, or educational in a generic way
	•	Make it fit naturally with the existing document

Output
	•	Update CLAUDE.md in place
	•	Rewrite Phase 4 into a task-type-aware coaching section aligned with the current Phase 3 model
	•	Briefly summarize:
	•	what changed in Phase 4
	•	how debugging coaching now aligns with Entry Modes and Interview Runtime Flow
	•	any tiny non-Phase-4 edits made only for consistency