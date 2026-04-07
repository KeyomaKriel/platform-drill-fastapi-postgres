
Update CLAUDE.md with a second-pass refinement focused only on Phase 1 and Phase 2.

Do not spend effort refining Phase 3 or Phase 4 in this pass.

Context

The new CLAUDE.md already has the right overall structure:
	•	Phase 1 = baseline bootstrap and verification
	•	Phase 2 = scenario workspace generation
	•	Phase 3 = interview simulation and evaluation
	•	Phase 4 = guided coaching

This pass is not a major structural rewrite.

This pass is to fix the main remaining weaknesses in Phase 1 and Phase 2:
	•	Phase 1 still reads too much like “build my practice lab exactly this way” instead of clearly presenting the current setup as the chosen baseline implementation for this practice system
	•	the boundary between source repo and scenario workspace is still too loose
	•	the session log path currently points to the source repo instead of the scenario workspace model
	•	Phase 2 task preparation is good conceptually, but task-selection rules and non-debugging task mechanics need tightening
	•	implementation/change and verification/trade-off tasks need clearer realism constraints

Main goals for this pass

1. Tighten Phase 1 framing without replacing the current implementation

Do not throw away the existing Phase 1 setup steps if they are still useful.

Instead:
	•	keep the current practical implementation if it is the chosen baseline for this drill system
	•	but rewrite the framing so it is clearly presented as this practice system’s canonical baseline implementation, not as some universal ideal or assumed interview environment
	•	make it clear that the point of Phase 1 is to establish a stable, reusable, known-good baseline for drills

In other words:
	•	preserve the current implementation details where useful
	•	improve the framing and operational intent

2. Make the source repo boundary explicit and strict

This is the most important refinement in this pass.

The file should clearly state that:
	•	the source repo is a manually curated canonical template
	•	Phase 1 may read from it, build from it, deploy from it, and verify it
	•	Phase 1 may not rewrite, regenerate, restructure, or mutate the source repo unless the user explicitly instructs it to do so
	•	drills must not directly mutate the source repo
	•	all user drill work happens in a fresh scenario workspace

Make this boundary operationally clear, not just conceptual.

3. Tighten scenario workspace rules

Make the scenario workspace model more concrete and consistent.

Clarify things like:
	•	what must be copied into the workspace
	•	what must not be copied
	•	what the workspace is expected to contain
	•	how it should remain a coherent interview-style repo
	•	that each drill must start from a fresh workspace derived from the canonical source repo

Do not leave this at the level of “copy relevant contents.”

Make the rule concrete enough that Claude Code can execute it consistently.

4. Fix the session log / artefact path model

The current log path still reflects the old source-repo-centric design.

Update the file so the logging and drill artefact story matches the workspace-based design.

Choose a clean, consistent model for:
	•	session log location
	•	any scenario-specific artefacts
	•	how those relate to the scenario workspace versus the canonical source repo

Prefer a model that matches the new “fresh workspace per drill” approach.

5. Tighten Phase 2 task preparation mechanics

Phase 2 task types are good, but the preparation rules need to be more concrete.

Improve:
	•	how Claude chooses among task types
	•	how it varies them across drills
	•	how it avoids drifting into unrealistic tasks
	•	how it keeps each drill focused on one primary thread of work

For task selection:
	•	keep “healthy orientation” as the preferred first drill type
	•	after that, add clearer selection rules so task choice is not too arbitrary

6. Tighten realism constraints for non-debugging tasks

For small implementation/change tasks:
	•	keep them realistic for a short live interview
	•	avoid drifting into overly artificial or overly platform-heavy exercises
	•	prefer tasks that feel like plausible small repo/deployment changes in an interview setting

For verification/trade-off tasks:
	•	require repo and/or runtime inspection before accepting high-level reasoning
	•	do not allow these tasks to degrade into generic opinion answers
	•	make evidence-based reasoning an explicit requirement in the task preparation and evaluation model

7. Keep the file operational

Do not turn the file into abstract prose.

Keep:
	•	concrete instructions
	•	decision rules
	•	operational boundaries
	•	clear definitions
	•	practical workflows

Constraints
	•	Focus on Phase 1 and Phase 2
	•	Do not do a broad rewrite of Phase 3 and Phase 4 in this pass
	•	Keep the overall structure intact
	•	Preserve useful existing mechanics unless you replace them with something better
	•	Keep the tone practical, strict, and operational

Output
	•	Update CLAUDE.md in place
	•	Improve only what is necessary for this second pass
	•	Prioritise:
	1.	source repo vs workspace boundary
	2.	Phase 1 framing
	3.	workspace/log path consistency
	4.	tighter Phase 2 task-prep mechanics