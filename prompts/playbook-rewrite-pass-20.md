Use this prompt:

:::writing{variant=“standard” id=“28764”}
Rename the current playbook.md to playbook-old-2.md.

Then create a new playbook.md from scratch.

Files to use

Read and use:
	•	CLAUDE.md
	•	troubleshooting-routing-tree.md
	•	playbook-old-2.md

Priority order:
	1.	CLAUDE.md = source of truth for the interview model, scope, and core principles
	2.	troubleshooting-routing-tree.md = source of truth for the troubleshooting routing / branching structure
	3.	playbook-old-2.md = source of reusable material only (commands, interpretations, fix patterns, narration, docs links)

Goal

Create a new playbook.md that is a practical Kubernetes troubleshooting handbook for this interview prep system.

It must be fully aligned to:
	•	the repo-based interview context and scope in CLAUDE.md
	•	the routing/branching truth in troubleshooting-routing-tree.md

The new handbook must not inherit the old routing problems.

Core requirements

1. Build the new handbook around the routing tree

This is the most important requirement.

The new playbook.md must follow the routing logic in troubleshooting-routing-tree.md.

That means:
	•	symptom first, root cause second
	•	pod-state routing is central
	•	CrashLoopBackOff is a symptom hub, not usually the final answer
	•	logs route from CrashLoopBackOff to the root-cause domain
	•	healthy pods route into pod -> service -> ingress testing
	•	special branches like RBAC, namespace confusion, rollout, PVC issues, and jobs fit where the routing tree says they fit

2. Keep it aligned with the interview context and scope

The new handbook must fit this interview prep system:
	•	repo-based practical interview
	•	repo-first orientation
	•	realistic app/deployment/runtime troubleshooting
	•	likely interview grain
	•	no drift into deep cluster-admin or generic platform breadth

Do not make it a generic Kubernetes handbook.

3. Make the troubleshooting sequence explicit

The handbook should make the practical method crystal clear.

It should strongly reflect the core sequence:
	•	repo-first orientation
	•	choose entry mode
	•	check pod state
	•	if pods broken, classify symptom
	•	if CrashLoopBackOff, use logs to route to root cause
	•	if pods healthy, test pod -> service -> ingress
	•	special branches where relevant
	•	apply smallest justified fix
	•	verify end-to-end

4. Make symptom vs root-cause distinction explicit

This is critical and must be built into the structure.

The handbook must clearly teach:
	•	symptoms are where you start
	•	root-cause domains are where the fix lives

Examples like CrashLoopBackOff and 503 can be used as examples only where helpful, but do not overfit the whole handbook to those examples.

5. Reuse the good material from playbook-old-2.md

Do not ignore the old handbook.

Reuse and adapt its strongest material where appropriate:
	•	commands
	•	output interpretation
	•	likely fixes
	•	verification steps
	•	narration guidance
	•	official Kubernetes docs references

But only reuse content if it fits the new structure and routing truth.

6. Improve practical usability

The new handbook must be genuinely useful for hands-on drills and learning.

That means:
	•	no section should strand the user
	•	routing between sections should be explicit
	•	entry criteria should not be overly gatekeeping
	•	placeholders like <key> should be explained practically
	•	command examples should be clear and usable

7. Preserve the right level of detail

This should still be a handbook, not a tiny cheat sheet.

Keep:
	•	Rule 0
	•	Repo-First Orientation
	•	Entry Modes
	•	Interview Runtime Flow
	•	Symptom-to-Domain Table
	•	Failure domains
	•	Quick Reference
	•	appendices where useful

But rebuild them so they serve the new routing structure properly.

Suggested structure

Use this as the rough shape unless you have a clearly better version:
	1.	Title and short framing
	2.	Rule 0
	3.	Repo-First Orientation
	4.	Entry Modes
	5.	Troubleshooting Sequence / Runtime Flow
	6.	Symptom vs Root-Cause explanation
	7.	Symptom-to-Domain Table
	8.	Failure Domains
	•	structured to match the routing tree and current drill model
	9.	Quick Reference
	10.	Appendices

Important note on failure domains

The main root-cause domains should align with the current drill model:
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

If you keep sections like Deployment / Rollout or Jobs / CronJobs, place them in a way that reflects their real role in the routing tree, not as equally primary root-cause buckets unless that is justified.

Constraints
	•	Rename the old file to playbook-old-2.md
	•	Create a brand new playbook.md
	•	Do not do a vague rewrite
	•	Do not let old routing problems survive
	•	Do not drift from CLAUDE.md
	•	Do not drift from troubleshooting-routing-tree.md
	•	Keep it practical, explicit, and usable for drills

Output

After creating the new file, briefly summarize:
	•	that playbook.md was renamed to playbook-old-2.md
	•	how the new playbook.md is structured
	•	how it was aligned to CLAUDE.md
	•	how it was aligned to troubleshooting-routing-tree.md
	•	what important material was reused from the old handbook
:::