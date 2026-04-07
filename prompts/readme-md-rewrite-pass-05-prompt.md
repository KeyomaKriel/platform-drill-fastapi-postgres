
Create a new README.md for this drill system.

Do not write a generic project README. Write it for me as the operator/user of the drill system, so I can quickly understand how to use it in practice.

Goal

The README should explain, in a practical and no-nonsense way, how to actually run this drill system end to end.

It should answer questions like:
	•	What is this folder?
	•	What are source-repo/, workspaces/, drills/, and CLAUDE.md for?
	•	What do I do first?
	•	What commands or phrases do I say to Claude Code?
	•	What happens in Phase 1, Phase 2, Phase 3, and Phase 4?
	•	What does a normal drill cycle look like?
	•	Where do logs go?
	•	Where does feedback go?
	•	What gets deleted and what persists?
	•	What should I edit manually vs what should Claude Code handle?
	•	How do I reset cleanly if things get messy?

Audience and tone

Write for the human running the system, not for a contributor or maintainer.

The tone should be:
	•	practical
	•	direct
	•	easy to skim
	•	explicit
	•	not fluffy

Assume I may forget details later and want the README to tell me exactly what to do.

Structure requirements

Include these sections, or very close equivalents:
	1.	What this is
	•	Short explanation of the drill system and what it is for
	2.	Folder structure
	•	Explain the role of:
	•	CLAUDE.md
	•	source-repo/
	•	workspaces/
	•	drills/drill-feedback/
	•	playbook.md
	•	any other important root-level files/folders
	3.	How the system works
	•	Brief explanation of the phases:
	•	Phase 1 = baseline bootstrap / verification
	•	Phase 2 = fresh drill workspace generation + task setup
	•	Phase 3 = silent interviewer / evaluation
	•	Phase 4 = guided coaching
	4.	Typical workflow
	•	A step-by-step “normal use” flow, for example:
	•	open Claude Code in this folder
	•	run Phase 1
	•	start a drill
	•	go to the workspace
	•	start the session log
	•	do the task
	•	come back for evaluation
	•	repeat
	5.	Exact phrases / prompts I can use with Claude Code
	•	Give practical examples like:
	•	“run phase 1”
	•	“start phase 2”
	•	“next scenario”
	•	“evaluate my fix”
	•	“coach me on this one”
	•	“back to phase 3”
	•	“just break something”
	•	Explain briefly what each one does
	6.	Session logs, workspaces, and feedback
	•	Explain:
	•	where the workspace is created
	•	where session.log lives
	•	what gets deleted after a drill
	•	where persistent feedback files go
	7.	Important operating rules
	•	Examples:
	•	source repo is the canonical template and should not be mutated during drills
	•	all drill work happens in fresh workspaces
	•	Phase 1 is for baseline setup, not for random edits
	•	if I want to change the template repo itself, that is a separate intentional action
	8.	Reset / cleanup
	•	Explain what to do if the system gets messy or a drill goes wrong
	•	Include the high-level recovery path, without making up commands that do not match the current system
	9.	Common usage patterns
	•	Examples:
	•	I want a normal drill
	•	I want debugging only
	•	I want coaching instead of testing
	•	I want to inspect the repo first
	•	I want another scenario
	10.	Quick start

	•	End with a short “if you just want to begin right now, do this” section

Important constraints
	•	Base the README on the current actual drill system structure, not an imaginary one
	•	Do not rewrite CLAUDE.md
	•	Do not invent folders or workflows that do not exist
	•	Do not turn the README into contributor documentation
	•	Do not make it abstract — make it usable

Output
	•	Create README.md
	•	Make it something I can genuinely use later without having to re-figure out how the system works
