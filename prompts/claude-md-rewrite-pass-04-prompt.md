Update CLAUDE.md with a small, targeted refinement only.

Do not do a broad rewrite. Do not change the overall phase structure.

Goal

Add a short operational section called:

Drill Scope and Coverage Model

Place it in the most useful location near Phase 2, ideally after the task types and before the task selection rules, unless there is a clearly better nearby location.

What this section must do

This section should make the intended drill scope more explicit so task generation stays aligned to realistic interview practice and does not drift.

It must define:

1. Primary focus

These are the main kinds of drills that should dominate practice:
	•	single-fault debugging of app / deployment / runtime issues in Kubernetes
	•	repo orientation
	•	small practical repo / config / deployment changes
	•	evidence-based verification and trade-off reasoning

2. Secondary focus

These can appear occasionally when they fit the repo and task naturally:
	•	limited infra-adjacent tasks such as probes, resource tuning, labels, startup behaviour
	•	occasional manifest-level additions or adjustments if they fit the repo and remain realistic for a short interview task

3. Out-of-scope

These should generally be avoided unless the user explicitly requests them:
	•	deep cluster internals
	•	multi-root-cause chaos
	•	major infrastructure buildout
	•	advanced platform features not already supported by the repo
	•	long architecture / system-design tasks disguised as drills

Important requirement

Do not make this section purely descriptive.

It must also tell Claude Code how to use the model operationally:
	•	primary focus should dominate drill generation
	•	secondary focus should appear occasionally and only when it fits naturally
	•	out-of-scope items should not be used unless the user explicitly asks for them
	•	task generation should stay close to the likely interview grain

Constraints
	•	Keep this a small targeted update
	•	Do not rewrite unrelated sections
	•	Keep the tone practical and operational
	•	Make the section fit naturally with the existing Phase 2 content

Output
	•	Update CLAUDE.md in place
	•	Briefly state where you inserted the section and whether you made any small surrounding edits for coherence