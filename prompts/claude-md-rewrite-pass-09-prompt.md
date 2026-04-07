
Refactor CLAUDE.md to reduce its size and improve performance without weakening the drill system.

Do not do a broad conceptual rewrite. The system architecture is already good. This is a responsibility and compression pass.

Goal

Make CLAUDE.md smaller, tighter, and easier for Claude Code to use by keeping it focused on operating the drill system, while moving or trimming content that now properly belongs in playbook.md or README.md.

The target is to reduce size meaningfully, especially by removing duplication and over-detailed reference material.

Files to use

Read and use:
	•	CLAUDE.md
	•	playbook.md
	•	README.md (if present)

Core principle

Use this separation of responsibility:
	•	CLAUDE.md = operating manual for running the drill system
	•	playbook.md = detailed Kubernetes troubleshooting handbook / study reference
	•	README.md = human-facing usage guide for operating the system

That means CLAUDE.md should focus on:
	•	what mode the system is in
	•	what should happen next
	•	how phases behave
	•	what the task types are
	•	what the failure-domain taxonomy is at a high level
	•	what the evaluation/coaching rules are
	•	what files/folders/paths are used
	•	what counts as success
	•	what to do for cleanup/reset

It should not carry lots of duplicated handbook-level reference detail if that now exists in playbook.md.

Main instructions

1. Keep the system architecture intact

Preserve the current overall architecture:
	•	Phase 1 = baseline bootstrap and verification
	•	Phase 2 = scenario workspace generation
	•	Phase 3 = interview simulation and evaluation
	•	Phase 4 = guided coaching

Do not change the drill model unless a tiny wording change is needed for clarity.

2. Remove or compress duplicated troubleshooting reference detail

Trim CLAUDE.md anywhere it duplicates material that is now better housed in playbook.md.

Examples of likely trim targets:
	•	long signal-to-bucket tables
	•	bucket-specific diagnostic command lists
	•	long debugging reference material
	•	excessive narration examples
	•	deeply explanatory troubleshooting content that belongs in the handbook

Do not remove the existence of these concepts entirely.

Instead:
	•	keep the high-level operational rules in CLAUDE.md
	•	refer to playbook.md for detailed troubleshooting guidance where appropriate

Example direction:
	•	keep the top-level failure domains in CLAUDE.md
	•	keep the evaluation rules
	•	keep the simulation/coaching flow
	•	but shorten detailed debugging reference sections and say to use playbook.md for the detailed runtime flow, domain diagnostics, and command interpretation

3. Keep Phase 3 and Phase 4 operational, but leaner

Phase 3 and 4 should still be fully usable.

Do not gut them.

But trim anything that is primarily:
	•	handbook content
	•	study material
	•	repeated examples
	•	long troubleshooting detail better housed in playbook.md

Phase 3 should still clearly define:
	•	task-type-aware simulation behaviour
	•	what to verify
	•	what good performance looks like
	•	evaluation criteria
	•	debugging failure domains at a top level
	•	hidden fault injection rules
	•	feedback file rules
	•	playbook update rules

Phase 4 should still clearly define:
	•	task-type-aware coaching behaviour
	•	coaching format
	•	coaching rules
	•	transition back to Phase 3

But both phases should be more concise and should lean on playbook.md for detailed troubleshooting depth.

4. Preserve the source-repo/workspace model

Do not weaken the filesystem model:
	•	drill system root
	•	source-repo/
	•	workspaces/
	•	drills/drill-feedback/
	•	session log model

These are important operational instructions and should stay.

5. Keep the failure-domain taxonomy, but concise

Keep the top-level debugging failure domains in CLAUDE.md, aligned with the current drill model.

But do not keep large amounts of bucket-level troubleshooting detail if that already lives in playbook.md.

A concise high-level list is enough in CLAUDE.md as long as Phase 3 can still use it operationally.

6. Reduce repeated narration material

If narration examples appear in multiple places and are mainly study material, trim them.

playbook.md is the better place for rich spoken-practice examples.

Keep only what is needed in CLAUDE.md for:
	•	simulation behaviour
	•	coaching behaviour
	•	evaluation expectations

7. Add explicit references to supporting files where helpful

Where detailed operational reference has been trimmed, explicitly point Claude Code to the right place.

Examples:
	•	use playbook.md for detailed Kubernetes troubleshooting runtime flow, failure-domain diagnostics, and spoken-practice guidance
	•	use README.md for human-facing usage/orientation if relevant

Do not overdo this, but make the separation of roles clear.

Constraints
	•	Do not do a major redesign
	•	Do not weaken the drill system
	•	Do not remove important operational rules
	•	Do not make CLAUDE.md abstract or vague
	•	Do not move content into new files unless clearly necessary — prefer trimming and referencing the files that already exist
	•	Keep the tone practical, strict, and operational

Output

Update CLAUDE.md in place.

After editing, provide a short summary of:
	•	what kinds of content were trimmed or compressed
	•	what was kept in CLAUDE.md
	•	what is now explicitly delegated to playbook.md or README.md
	•	whether there are any remaining obvious large sections that could still be split later if needed