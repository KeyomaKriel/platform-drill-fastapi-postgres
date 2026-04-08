
Yes — update the system to fix that gap.

The issue is not that literally every resource in a real interview would always be in the repo. Some cluster-supporting infrastructure can still exist outside it.

But for this drill system, the candidate-relevant resources should be in the source repo if I am expected to reason about them repo-first.

Right now the source repo is missing important resources that Phase 1 creates directly in the cluster:
	•	Ingress
	•	NetworkPolicies
	•	ServiceAccount / RBAC
	•	init-container-related deployment config
	•	resource requests / limits
	•	any other candidate-relevant manifest that affects how the app is supposed to run

That weakens the repo-based interview simulation.

What I want you to do

1. Update the source repo

Add the missing candidate-relevant manifests/config into ./source-repo/ so the repo more accurately reflects the deployed application.

The source repo should contain the resources a candidate would reasonably inspect or modify in a repo-based Kubernetes interview.

Keep cluster-bootstrap/supporting infrastructure outside the source repo where appropriate (for example things like the ingress controller installation itself, Calico installation, kind cluster creation, etc.).

2. Update CLAUDE.md Phase 1 accordingly

Phase 1 currently creates several app-relevant resources directly in the cluster because they are not in the repo.

Update Phase 1 so that:
	•	it prefers using the manifests/config that now exist in ./source-repo/
	•	it treats the source repo as the canonical candidate-facing application/deployment definition
	•	it only creates/apply inline resources directly when they are truly supporting infrastructure and not candidate-facing repo content
	•	the wording clearly distinguishes:
	•	repo-defined application resources
	•	non-repo cluster-supporting infrastructure

3. Preserve the core design

Keep:
	•	the stable baseline model
	•	the fresh workspace per drill model
	•	the source repo as manually curated canonical template
	•	Phase 1 as baseline bootstrap/verification, not random mutation

4. Keep realism in mind

I do not need the repo to include literally everything in the cluster.

But I do want the repo to include the important resources a candidate should inspect in a repo-based practical interview.

So use this rule:
	•	if a candidate is expected to understand, reason about, troubleshoot, or modify it, it should usually be in ./source-repo/
	•	if it is cluster-supporting plumbing for the drill system itself, it can stay outside the repo and be created by Phase 1

Output

Please:
	1.	update the source repo to include the missing candidate-relevant manifests/config
	2.	update CLAUDE.md Phase 1 to match
	3.	briefly summarize:
	•	what was added to ./source-repo/
	•	what Phase 1 now does differently
	•	what still remains outside the repo as supporting infrastructure
