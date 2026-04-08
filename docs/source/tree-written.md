

Troubleshooting Routing Tree

0. First principle

Do not guess.
Start from:
	•	visible symptom
	•	nearest layer/object
	•	fastest truth-revealing command.  ￼

⸻

1. Repo-first orientation

Before deep Kubernetes work, build a quick mental model:
	•	What does the app do?
	•	What endpoints probably exist?
	•	What dependencies does it have?
	•	What env vars/config matter?
	•	How does it start in the container?
	•	How is it deployed in Kubernetes?
	•	What is the deploy/apply path?

Then move to cluster inspection.

⸻

2. Choose entry mode

If scope is unclear

Use Full Triage:
	•	context
	•	namespaces
	•	pods
	•	deploys
	•	services
	•	ingress
	•	recent events.  ￼

If app/workload is already known

Use Fast Path:
	•	pods
	•	describe pod
	•	logs
	•	then reachability layer by layer.  ￼

⸻

3. Main routing sequence

Step A — Check pod state

kubectl get pods

If pods are not healthy
Branch by pod symptom:
	•	ImagePullBackOff / ErrImagePull / CreateContainer*
-> Image pull / container creation
	•	CrashLoopBackOff / Error / Init:*
-> Startup / crash
then route again based on logs
	•	Running but 0/1
-> Probe failure
	•	Running, Ready, but restarts climbing
-> Probe failure or Startup / crash
	•	Pending
-> Resource / scheduling / storage

If pods are healthy
Move to service path testing.

⸻

4. If pod symptom is CrashLoopBackOff / Startup-Crash

This is a symptom hub, not always the root cause.

First:
	•	describe pod
	•	logs
	•	logs --previous
	•	init container logs if relevant.  ￼

Then branch by what the logs say

If logs show:
	•	missing ConfigMap/Secret
	•	wrong env reference name
	•	wrong key reference
-> Config / Secret / env

If logs show:
	•	Name or service not known
	•	bad hostname
	•	service discovery failure
-> DNS / service discovery / namespace
and possibly Config / Secret / env if the hostname value itself is wrong

If logs show:
	•	connection refused
	•	auth failure
	•	wrong DB name
	•	dependency reachable issue
-> Application-level dependency / runtime
and possibly Config / Secret / env if the actual config value is wrong

If logs show:
	•	OOMKilled / exit 137
-> Resource / scheduling / storage

If logs show:
	•	command not found / bad entrypoint / container startup problem
-> Image pull / container creation or Startup / crash

If logs show:
	•	app is fine but killed by probes
-> Probe failure

So the rule is:

CrashLoopBackOff tells you where to start.
Logs tell you the root-cause branch.

⸻

5. If pods are healthy, test reachability layer by layer

A. Pod

Port-forward pod and curl a likely path.
If pod itself does not respond:
-> Application-level dependency / runtime
or Config / Secret / env  ￼

B. Service / Endpoints

Check endpoints and service mapping.

If endpoints are empty
	•	selector mismatch
	•	pods not Ready
-> Service routing / port / endpoint
or go back to Probe failure if readiness is the real reason

If service port/targetPort mismatched
-> Service routing / port / endpoint

C. Ingress / External path

If service works but external path fails:
-> Ingress / external routing

D. If everything looks healthy but traffic silently fails

-> NetworkPolicy / traffic restriction

⸻

6. Special branches

Forbidden / Unauthorized

-> RBAC / service account / permission

Resources appear missing

-> DNS / service discovery / namespace
especially namespace confusion

PVC issues / storage bind issues

-> Resource / scheduling / storage

Rollout stuck

This is usually not a root-cause endpoint by itself.
Check the new pods:
	•	image issue -> Image pull / container creation
	•	crash -> Startup / crash
	•	not ready -> Probe failure
Deployment / rollout is more of a rollout-view branch than a core root-cause branch.  ￼

Job / CronJob issue
	•	if job pod fails -> route into the same normal branches
	•	if schedule/suspend issue -> Jobs / CronJobs reference section.  ￼

⸻

7. Root-cause domains you should memorize

These are the main root-cause buckets from the drill model:
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
	•	Application-level dependency / runtime failure.  ￼

⸻

8. Fix rule

Once you identify the root cause:
	•	apply the smallest justified fix
	•	change one thing for one reason
	•	do not shotgun multiple edits.  ￼

⸻

9. Verification sequence

After any fix:

Verify in this order
	•	pod state healthy
	•	endpoints populated
	•	service path works
	•	ingress/external path works
	•	expected app response works end-to-end.

Do not stop at “pods are Running.”

⸻

Very compressed interview version

Troubleshooting sequence
	1.	Repo-first orientation
	2.	Choose entry mode
	3.	Check pods
	4.	If pods broken, classify pod symptom
	5.	If CrashLoopBackOff, use logs to route to root cause
	6.	If pods healthy, test pod -> service -> ingress
	7.	If traffic silently fails, think NetworkPolicy
	8.	If auth/Forbidden, think RBAC
	9.	Apply smallest justified fix
	10.	Verify end-to-end

⸻

Most important conceptual rule

Symptom first, root cause second.

Examples:
	•	CrashLoopBackOff is a symptom
	•	wrong DB hostname is root cause
	•	503 is a symptom
	•	no ready backends may be root cause
	•	pods crashing may be deeper root cause
