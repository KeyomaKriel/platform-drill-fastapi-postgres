You are editing the current playbook.md.

Your job is to transform it into a Kubernetes troubleshooting handbook for interview practice that is also explicitly aligned with the current CLAUDE.md drill system.

Do not create the separate short live-use playbook yet. That will be done later.

Files to use

Read and use:
	•	playbook.md
	•	CLAUDE.md

You may also use the existing rewrite instructions in:
	•	playbook-rewrite-pass-03.md

But if there is any conflict, prefer:
	1.	this prompt
	2.	CLAUDE.md
	3.	the current playbook.md
	4.	playbook-rewrite-pass-03.md

Core goal

Produce a revised playbook.md that:
	•	reads as a handbook, not a minimal runtime playbook
	•	is aligned with the interview structure and scope in CLAUDE.md
	•	is stronger for spoken-practice
	•	is better linked internally
	•	includes relevant official Kubernetes docs references
	•	preserves the strongest parts of the existing structure

Critical alignment requirement

This rewrite must align playbook.md with the current CLAUDE.md model.

That means the handbook should clearly fit the drill system’s actual logic:
	•	repo-based interview practical task
	•	repo-first orientation before or alongside cluster inspection
	•	Phase 3 debugging flow and failure-domain taxonomy
	•	likely interview grain rather than generic Kubernetes breadth
	•	strong emphasis on:
	•	orientation
	•	hypothesis-driven debugging
	•	smallest justified fix
	•	end-to-end verification
	•	spoken reasoning

Do not treat the handbook as an isolated Kubernetes reference. It should support the actual drill model defined in CLAUDE.md.

Scope constraints
	•	Edit only playbook.md
	•	Do not rewrite from scratch unless a section is beyond repair
	•	Preserve the current overall structure where it is already strong
	•	Improve the document so it works clearly as a handbook
	•	Keep it practical and interview-oriented

Main goals

1. Reposition the file as a handbook

Update the title and framing so the document is clearly a handbook, not a pure playbook.

It should still be useful for interview practice, but it should stop pretending to be only the tightest possible live-use artifact.

That means:
	•	keep the runtime flow
	•	keep the failure domains
	•	keep the quick reference
	•	but make the document comfortable being deeper and more explanatory

2. Align the failure-domain taxonomy with CLAUDE.md

This is important.

Update the top-level failure-domain framing so it aligns with the current debugging taxonomy in CLAUDE.md.

The primary top-level debugging buckets should align with the current CLAUDE.md failure domains:
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

Use judgment about section titles and editorial structure:
	•	keep existing sections where they are already strong
	•	merge/rename/reframe where needed for alignment
	•	preserve useful subcases and detailed commands from the existing file
	•	do not throw away good material just because the naming changes

If sections like Deployment / Rollout or Jobs / CronJobs still belong, keep them in a way that fits the new model:
	•	likely as secondary sections, subcases, or clearly marked reference sections
	•	not as if they are equally central first-line interview buckets unless that really makes sense

3. Add much stronger spoken-practice support

This is one of the most important changes.

For each major failure-domain section, add a more explicit and useful spoken-practice block.

Do not just keep one short “Say:” line if it is too vague.

Where useful, add a compact spoken block with things like:
	•	what I’m seeing
	•	what that most likely means
	•	what I’m checking next
	•	why I am checking that next

These spoken prompts should help with interview narration practice.

They should sound:
	•	natural
	•	operational
	•	concise enough to use
	•	not robotic
	•	not overly polished

Make them materially more helpful than the current version.

4. Add official Kubernetes docs references where applicable

For each major failure-domain section, add a short Official docs subsection or line with 1–3 relevant official Kubernetes documentation links.

Rules:
	•	Prefer official Kubernetes docs only
	•	Do not spam links
	•	Use only links that genuinely match the section
	•	Put the links where they are easy to find, ideally near the end of the section
	•	Use descriptive link text, not raw URLs

Sections likely to benefit:
	•	RBAC
	•	Image pull / container creation
	•	Startup / crash / pod debugging
	•	Probe failure
	•	Config / Secret / volume injection
	•	Resource / scheduling / storage
	•	Service routing
	•	DNS / service discovery if appropriate
	•	Ingress
	•	NetworkPolicy
	•	Deployment / Rollout
	•	Jobs / CronJobs

If a section does not have a strong official-doc equivalent, do not force weak links.

5. Add internal links everywhere they should obviously exist

Wherever the document says things like:
	•	go to
	•	see
	•	check
	•	move to
	•	refer to
	•	use the section below
	•	or references another section by name

turn those into proper internal Markdown links.

Also:
	•	keep the table of contents correct
	•	make sure anchors/headings and internal links are consistent
	•	prefer actual inline links instead of plain-text references

6. Preserve the strongest current structure

The current structure is mostly right. Keep and improve:
	•	Rule 0
	•	Entry Modes
	•	Interview Runtime Flow
	•	Symptom-to-Domain Table
	•	Failure Domains
	•	Quick Reference
	•	appendices

Do not collapse everything into a messy mixed taxonomy.
Do not remove the failure-domain organization.

7. Keep the handbook practical, not academic

This should still feel like a serious troubleshooting handbook for interview drills.

For each failure domain, preserve and refine:
	•	Start here if
	•	Commands
	•	What the output usually implies
	•	Likely fixes
	•	Verify
	•	Spoken practice help
	•	Official docs links where appropriate

Do not turn it into a textbook.

8. Preserve and improve the current distinctions

Keep the current stronger distinctions, especially:
	•	Full Triage vs Fast Path
	•	runtime flow vs deeper reference material
	•	Config / Secret / env failure vs Application-level dependency / runtime failure
	•	Service routing vs Ingress
	•	sandbox interview behaviour vs production-minded reasoning where relevant

9. Add repo-first interview alignment where it belongs

The handbook should still be primarily a Kubernetes troubleshooting handbook, but it now needs to fit the repo-based interview model from CLAUDE.md.

That means:
	•	where appropriate, explicitly acknowledge repo-first orientation
	•	make sure the runtime flow and failure-domain framing do not ignore the repo/deploy-path context
	•	do not turn the handbook into a repo handbook, but do make it compatible with the repo-first drill model

10. Keep app-specific assumptions under control

Do not reintroduce hard-coded app-specific assumptions.

Where you mention paths like /, /health, etc.:
	•	keep them as common guesses or examples
	•	do not imply they are guaranteed
	•	where useful, explicitly say “or a known app path from the scenario”

11. Improve naming and framing where needed

If the current file still reads too much like a playbook in places, adjust the wording so it reads more naturally as a handbook.

That can include:
	•	title
	•	intro wording
	•	section intros
	•	wording around runtime flow vs reference material

But do not destroy the practical nature of the document.

Specific editorial expectations

Spoken-practice guidance

For each major failure domain, provide materially better narration support.

A good pattern is something like:
	•	What I’m seeing
	•	What that suggests
	•	What I’m checking next
	•	Why that is the next check

This can be presented as:
	•	a short spoken block
	•	a “Say this out loud” subsection
	•	or something similarly readable

Official docs references

At the end of relevant sections, add something like:

Official docs
	•	[Descriptive official doc link]
	•	[Descriptive official doc link]

Use Markdown links.

Internal links

Wherever one section sends the reader elsewhere, make that a clickable internal link.

Examples:
	•	“Go to Probe Failure” should become a proper link
	•	“See Resource / Scheduling” should become a proper link
	•	“Check Application-Level Failure” should become a proper link

Do not leave obvious cross-references as plain text.

What not to do
	•	Do not create the separate short playbook yet
	•	Do not massively expand appendices
	•	Do not add weak or irrelevant documentation links
	•	Do not make the document generic and bland
	•	Do not remove useful detailed commands or fix patterns just to make it shorter
	•	Do not ignore CLAUDE.md
	•	Do not leave the handbook using an outdated failure-domain taxonomy if it conflicts with CLAUDE.md

Output requirements

Edit playbook.md in place.

After editing, provide a short summary of:
	•	how you reframed it as a handbook
	•	how you aligned it with CLAUDE.md
	•	what you changed in the spoken-practice guidance
	•	what official-doc references you added
	•	what internal linking improvements you made
	•	anything still left for a future dedicated short playbook file

Quality bar

The final document should feel like:
	•	a Kubernetes troubleshooting handbook
	•	good for interview practice and drills
	•	richer and more teachable than a strict playbook
	•	stronger for spoken practice
	•	better linked internally
	•	grounded with official Kubernetes doc references where relevant
	•	explicitly aligned with the current drill system in CLAUDE.md