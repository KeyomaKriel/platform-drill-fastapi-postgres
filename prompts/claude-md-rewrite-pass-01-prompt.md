Rewrite the interview-practice operating manual by creating a new CLAUDE.md from scratch, using the current file renamed to CLAUDE-old.md as source material.

This is a first-pass structural rewrite, not a final polish pass.

Context

The old file was built around the assumption that the interview would mainly be “an app deployed to Kubernetes” with break/fix drills.

Newer information suggests the real interview is more likely to be a repo-based practical task in a prepared environment, likely Codespaces or Codespaces-like, with engineers observing and lightly guiding.

So the new file must no longer treat Kubernetes break/fix as the whole frame. Kubernetes is still important, but it is one layer inside a repo-based task.

What to do
	1.	Rename the current file to CLAUDE-old.md.
	2.	Create a new CLAUDE.md from scratch.
	3.	Use CLAUDE-old.md as source material:
	•	preserve the strongest useful mechanics and standards
	•	do not preserve obsolete structure or wording just because it already exists

Critical model change
	•	Phase 1 is not the drill repo generation phase.
	•	Phase 1 should establish or verify a healthy, known-good template/source baseline and the supporting runtime environment.
	•	Phase 2 should create a fresh scenario repo/workspace for each drill from that baseline.
	•	Do not frame Phase 2 as merely mutating one shared repo in place, unless a specific implementation detail requires that internally.
	•	The intended feel is: each drill drops the user into a fresh, coherent repo/workspace that resembles a prepared interview tech-test repo.

Required phase structure

New Phase 1

A clean baseline bootstrap / restore / health-verification phase.

Its job is to:
	•	create or verify a known-good template/source baseline
	•	create or verify the runtime environment needed to support drills
	•	support both full bootstrap mode and fast health-check mode
	•	end with a clearly verified healthy baseline and a reset path

New Phase 2

Fresh drill repo/workspace generation and task preparation.

Its job is to:
	•	create a fresh scenario repo/workspace for the current drill from the healthy baseline/template
	•	prepare a realistic interview-style task
	•	not just “break the cluster”
	•	support task types such as:
	•	healthy orientation task
	•	single-fault debugging task
	•	small implementation/change task
	•	verification/trade-off task

It should prefer:
	•	copying a controlled template repo
	•	resetting from a known-good source repo
	•	generating a fresh workspace from a predefined scenario pattern

It should not invent arbitrary repo layouts per drill unless explicitly asked.

Renumber later phases
	•	The current Phase 2 content should become the new Phase 3
	•	The current Phase 3 content should become the new Phase 4

For this pass:
	•	focus mainly on rewriting and defining the new Phase 1 and new Phase 2 well
	•	carry forward and lightly adapt the later phases into new Phase 3 and Phase 4
	•	do not spend most of the effort polishing new Phase 3 and 4 yet
	•	we will do a second pass later to refine those sections in detail

Preserve from CLAUDE-old.md

Preserve and reuse the strongest parts where appropriate:
	•	systematic debugging emphasis
	•	hypothesis-driven behaviour
	•	smallest justified fix
	•	end-to-end verification
	•	communication and narration quality
	•	realism over puzzle design
	•	any good evaluation standards
	•	any good drill mechanics that still fit the new structure

Add stronger repo-first guidance

Make it explicit that good practice starts with:
	•	understanding the repo structure
	•	identifying the expected run/deploy path
	•	locating manifests/charts/scripts
	•	understanding how the app is supposed to work
	•	understanding how success should be verified

Do not make Kubernetes inspection the only valid starting point.

A strong candidate may begin with repo orientation before cluster inspection, and the new file should reflect that.

Keep the document operational and concrete

Do not rewrite this into a vague philosophy document.

The new CLAUDE.md must remain an operational manual.

That means:
	•	clear workflows
	•	clear decision rules
	•	practical instructions
	•	concrete definitions of things like:
	•	coherent repo baseline
	•	template/source baseline
	•	fresh scenario workspace
	•	healthy baseline
	•	reset path

Claude Code should be able to act on the document consistently.

De-emphasise or remove what is now over-weighted

Reduce or remove:
	•	cluster-sabotage framing as the main model
	•	infrastructure-heavy setup as if that were the interview itself
	•	assumptions that every task starts from a broken running cluster
	•	overfitting to one exact app shape
	•	anything that makes the practice feel like maintaining a lab rather than entering a realistic task repo

Keep local simulation acceptable

The environment does not have to literally be GitHub Codespaces.

But it should reproduce the key behaviours that matter:
	•	entering an unfamiliar repo
	•	inspecting it
	•	running/debugging a Kubernetes-deployed app
	•	making changes
	•	verifying them
	•	resetting cleanly for the next drill

Be explicit about fresh-workspace behaviour

The file should make clear that each drill should ideally start from a fresh scenario repo/workspace derived from a healthy template/source baseline.

Claude should avoid contaminating future drills with edits from previous ones.

If the implementation uses:
	•	copies
	•	branches
	•	temporary directories
	•	snapshots
	•	reset scripts

that is fine, but the operational intent must be a fresh drill workspace each time.

Important constraints
	•	Create a new CLAUDE.md from scratch; do not simply patch the old one in place
	•	Use CLAUDE-old.md as source material, not as a structure that must be preserved
	•	Do not remove useful drill mechanics unless you replace them with something better
	•	Do not make the new Phase 1 and Phase 2 too abstract to execute
	•	Keep the tone practical and strict
	•	The final file should feel like a serious operating manual for realistic interview practice, not a loose set of ideas

Output
	•	Rename current CLAUDE.md to CLAUDE-old.md
	•	Create a new full CLAUDE.md
	•	Ensure the new file has:
	•	new Phase 1
	•	new Phase 2
	•	current Phase 2 moved to new Phase 3
	•	current Phase 3 moved to new Phase 4
	•	Do a strong first-pass structural rewrite now; detailed refinement of new Phase 3 and 4 will happen later