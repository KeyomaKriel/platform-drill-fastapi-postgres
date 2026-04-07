
You are editing the current playbook.md.

This is a second-pass tightening edit, not a rewrite. The structure is now mostly right. Keep the current overall architecture and improve the remaining weak spots.

Important constraints:
	•	Edit only playbook.md
	•	Do not inspect or use any other files in the repo
	•	Do not rebuild from scratch
	•	Preserve the current top-level structure unless a small local change is clearly justified

Goal of this pass

Keep the current structure, but make it sharper, more realistic, and more internally consistent.

The current version is a good base. Your job is to refine it, not replace it.

High-priority changes

1. Reduce implicit app-specific/path-specific assumptions in the runtime flow

In Interview Runtime Flow, Fast Path, and any verify sections:
	•	Do not imply that /health is guaranteed to exist
	•	Do not imply that / or /health proves application correctness in every case
	•	Reword these sections to make clear that:
	•	/ and /health are common first guesses
	•	a known app path from the scenario is better if available
	•	port-forwarding and curl are often being used first to test reachability, not to assume a specific endpoint contract

Keep examples, but frame them as common probes or placeholders, not assumptions.

2. Sharpen Full Triage so it does not assume the namespace too early

In the Full Triage section:
	•	Make the flow work better when the namespace is not known yet
	•	Avoid assuming -n <ns> too early in a cluster-wide ambiguous scenario
	•	Improve the sequence so it is clearer how to go from:
	•	unknown scope / unknown namespace
	•	to likely namespace
	•	to focused triage

Do not make this section long. Just make it more realistic.

3. Make Image Pull / Container Creation match its title

Right now the section mostly covers image pull failures.

Expand it slightly so it also covers common container creation failures such as:
	•	CreateContainerConfigError
	•	CreateContainerError
	•	missing Secret/ConfigMap preventing container creation
	•	bad command / entrypoint / executable not found before app startup


4. Make DNS / Namespace / Service Discovery cleaner internally

Keep this as one top-level section, but split it more clearly into two explicit subsections:
	•	Namespace targeting / namespace confusion
	•	DNS / service discovery

Make the separation visually obvious and the ownership cleaner.

5. Clarify sandbox-vs-production posture in the NetworkPolicy section

Keep the temporary deletion technique if useful, but explicitly label it as:
	•	acceptable in an interview sandbox or drill environment
	•	not the default production approach

Do not remove the tactic entirely. Just frame it properly.

6. Standardise the Say: prompts

Keep them — they are useful for interview practice.

But make them more consistent:
	•	each major top-level section should have one narration cue
	•	multi-part sections can have an additional cue where helpful

7. Fix small formatting and command-quality issues

Review and fix minor rough edges, including but not limited to:
	•	the RBAC apiGroups example typo ([""]} style issue)
	•	any commands that are too loose or unrealistic as written
	•	any placeholders that are inconsistent with surrounding guidance
	•	any small formatting inconsistencies

Be conservative: tighten obvious rough edges without over-editing everything.

What not to change
	•	Do not replace the current top-level architecture
	•	Do not reintroduce the old mixed bucket structure
	•	Do not substantially expand the appendices
	•	Do not turn this into a generic Kubernetes guide
	•	Do not remove the useful distinction between runtime flow and failure-domain reference material
	•	Do not remove Deployment / Rollout as a standalone section

Output requirements

Edit playbook.md in place.

After editing, provide a short summary of:
	•	the concrete changes made
	•	any places where you intentionally left the current wording/structure as-is
	•	any issues that still remain but were not worth changing in this pass

Quality bar

This pass should make the document:
	•	less assumption-heavy
	•	more realistic under interview conditions
	•	more internally consistent
	•	cleaner without becoming generic