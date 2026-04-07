
You are rewriting playbook-old.md.

This is a from-scratch rewrite, but not a generic rewrite. You must use the existing playbook-old.md as source material and preserve its strongest content where useful. The current document has valuable commands, interpretations, fix patterns, verification steps, and interview narration cues. Do not discard that substance just because you are rebuilding the structure.

Your goal is to create a sharper Kubernetes troubleshooting playbook for practising a 60-minute interactive technical interview involving an app deployed to Kubernetes.

Important scope constraint:
	•	Read and use only playbook-old.md as source material.
	•	Do not inspect or use any other files in the repo unless I explicitly ask you to.
	•	Do not infer app behavior, endpoints, or architecture from other repo files.
	•	Treat this as an editorial rewrite of playbook-old.md, not a repo-wide analysis task.

Core design goals

1. Build the new playbook around the correct top-level structure

The current document uses a mixed taxonomy. The new document must use a cleaner structure based primarily on failure domains, while also having a very clear runtime investigation flow near the top.

Use this general top-level shape:
	•	Rule 0
	•	Entry mode selection:
	•	Full Triage
	•	Fast Path
	•	Interview Runtime Flow
	•	Quick Signal / Symptom-to-Domain Table
	•	Failure Domain Sections
	•	Short Quick Reference
	•	Optional appendices only if clearly useful

2. Make the two entry modes explicit

Near the top, create a short section that clearly explains:
	•	Full Triage = use when scope is ambiguous, multiple things may be broken, or the scenario is “investigate this cluster”
	•	Fast Path = use when there is a known app/workload and the symptom is already localised enough to begin directly

Do not present Fast Path as replacing full triage. They are peer entry modes.

3. Add a concise Interview Runtime Flow

Add a short section near the top called something like Interview Runtime Flow.

It should be the practical operational loop for live use. It should be short, direct, and easy to follow under pressure.

It should roughly follow this order:
	1.	Orient only enough to avoid wrong context/namespace
	2.	Identify the relevant workload if not already known
	3.	Check pod state
	4.	Describe the relevant pod
	5.	Check current and previous logs
	6.	If pod is healthy enough, test pod reachability directly
	7.	Then check Service and Endpoints
	8.	Then check Ingress / external path
	9.	If the issue is not a reachability path problem, branch into the relevant failure domain
	10.	Apply the smallest fix and verify

Make this clearly distinct from the rest of the document.

4. Use failure domains as the main section taxonomy

Rebuild the main troubleshooting sections around these domains:
	•	RBAC / service account / permissions
	•	Image pull / container creation
	•	Startup / crash
	•	Probe failure
	•	Config / Secret / env / volume injection
	•	Resource / scheduling / storage
	•	Service routing / ports / endpoints
	•	DNS / namespace / service discovery
	•	Ingress / external routing
	•	NetworkPolicy / traffic restriction
	•	Deployment / rollout
	•	Application-level failure
	•	Jobs / CronJobs

Notes:
	•	Keep Deployment / Rollout as a short standalone section. Do not remove it entirely, but do not let it dominate the structure.
	•	Do not keep Namespace Confusion as a standalone top-level section. Fold it into triage and/or DNS / namespace / service discovery.
	•	Do not recreate a giant umbrella bucket like the current Bucket B.

5. Preserve and reuse strong content from the current file

Mine the existing playbook for useful material and carry it forward into the new structure:
	•	diagnostic commands
	•	output interpretation
	•	likely fixes
	•	verification steps
	•	useful interview narration prompts

Do not preserve old sections just because they exist. Preserve the good content, not the old shape.

6. Clarify the Config vs Application boundary

Make the distinction clean:
	•	Config / Secret / env / volume injection section:
Kubernetes-side reference, injection, mount, or missing-object problems.
Examples: missing ConfigMap, wrong Secret reference, wrong injected key, mount path/reference issue.
	•	Application-level failure section:
The pod is up, Kubernetes looks healthy, but the app is still wrong.
Examples: app returns 5xx, wrong route behavior, bad runtime assumptions, schema/app logic issues, bad dependency behavior after startup.

Avoid overlap between these sections.

7. Split runtime playbook from reference material

The current file tries to be multiple documents at once. The new version must clearly separate:
	•	runtime guidance for live interview use
	•	reference material

The runtime sections must come first and feel primary.

Keep only a short quick reference in the main body.

Appendices are optional. If you keep them, they must be clearly secondary and trimmed to genuinely useful material only.

8. Reduce app-specific assumptions

Do not hard-code drill-specific endpoints like /items as though they are universal.

If you keep specific endpoint examples, label them clearly as scenario-specific examples.

Prefer generic placeholders or patterns like:
	•	/
	•	/health
	•	<known app path>

9. Keep interview narration support

The current “Say:” prompts are useful for interview practice so keep them and add more whereever necessary.

10. Keep sections operationally tight

For each failure domain section, use a practical structure such as:
	•	Start here if
	•	Commands
	•	What the output usually implies
	•	Likely fixes
	•	Verify

Specific instructions about old content

When rewriting:
	•	Reuse strong command sequences from the current file.
	•	Reuse good “what to look for” material.
	•	Reuse strong fix patterns where appropriate.
	•	Reuse useful verification steps.
	•	Reuse useful narration prompts.

But:
	•	do not preserve the old bucket naming
	•	do not preserve bloated appendices just because they exist
	•	do not preserve any section whose only value is completeness rather than practical usefulness

Output requirements

Produce a complete new playbook.md.

Also produce a short companion summary at the end of your response covering:
	•	major structural changes made
	•	which old sections were merged, split, or removed
	•	any sections where you deliberately kept important old content
	•	anything still questionable and worth a second pass

Quality bar

The final document should feel like:
	•	a serious interview-practice playbook
	•	structurally clean
	•	operationally usable
	•	richer than a generic rewrite
	•	clearer than the current version

Do not be timid. Be willing to reorganise, rename, merge, split, cut, and rewrite heavily.

But preserve the strongest substance from the current playbook wherever it genuinely helps.
:::