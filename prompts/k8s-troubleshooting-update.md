1. First commands to run for each symptom bucket

The sheet should not only say what the symptom maps to. It should also say what I run first.

For example:

If symptom is Start

First commands:

kubectl get pods
kubectl describe pod <pod>
kubectl get events --sort-by=.lastTimestamp

Then, depending on what you see:
	•	ErrImagePull / ImagePullBackOff → inspect image name, tag, pull secret, imagePullPolicy
	•	Pending → inspect scheduling reason, PVC, node constraints
	•	CreateContainerConfigError → inspect config/secret/env refs

If symptom is Stay up

First commands:

kubectl get pods
kubectl describe pod <pod>
kubectl logs <pod>
kubectl logs <pod> --previous

Then:
	•	CrashLoopBackOff → logs route you to actual cause
	•	0/1 Ready → probe path/port/startup timing
	•	restarts climbing → liveness, intermittent crash, OOM

If symptom is Receive Traffic

First commands:

kubectl get svc
kubectl describe svc <service>
kubectl get endpoints <service>
kubectl get endpointslices
kubectl port-forward svc/<service> 8080:<service-port>

Then:
	•	no endpoints → selector mismatch or pods not ready
	•	service works internally but not externally → ingress branch

If symptom is Reach Dep

First commands:

kubectl logs <pod>
kubectl exec -it <pod> -- sh
kubectl describe pod <pod>

Then test from inside the pod where relevant:
	•	DNS lookup
	•	TCP reachability
	•	env values present
	•	dependency hostname correctness

That would make the sheet much more interview-useful than just naming buckets.

⸻

2. “What I say” beside each first-command block

This is the second big improvement.

You do not just need commands. You need the narration line that makes you sound controlled.

Example:

Start

“The workload is failing before it can become a healthy running pod, so I want the scheduler/container creation signal first.”

Stay up

“The pod exists but is not stabilising, so I want pod state, describe output, and logs before I decide what branch this belongs to.”

Receive Traffic

“If the pod is healthy, I want to check routing layer by layer rather than guessing whether this is ingress or service.”

Reach Dep

“The app may be up but broken against something it depends on, so I want logs and then in-container checks if needed.”

That makes the sheet much stronger in a pair-programming setting.

⸻

3. A tiny “nearest truth source” rule box

This should be explicit and prominent.

Something like:

Nearest truth source
	•	Pod not healthy → describe pod + logs
	•	Pod healthy but app unreachable → Service / endpoints
	•	Service works but external path fails → Ingress
	•	App responds but feature fails → dependency path from inside app/pod

That is already implied by your current structure, but it should be stated bluntly. Your current tree file does this better than the visual.  ￼

⸻

4. “Do not conclude X from Y” guards

Very valuable for interviews.

Add a small block like:

Do not over-infer
	•	CrashLoopBackOff does not tell you the cause
	•	Running does not mean healthy
	•	Ready does not prove ingress works
	•	existing Service does not mean it has usable endpoints
	•	ingress object existing does not mean external routing works

This matters because your written tree already correctly distinguishes symptom from cause.  ￼  ￼

⸻

5. Verification commands, not just verification concepts

You already have the right verification logic in the tree: pod state healthy, endpoints populated, service path works, ingress path works, app works end to end.  ￼

But for interview use, the visual should say what to run.

Example:

kubectl get pods
kubectl get endpoints <service>
kubectl port-forward svc/<service> 8080:<service-port>
curl localhost:8080/health
kubectl get ingress
curl -H "Host: <host>" http://<ingress-address>/<path>

Without that, the verification section stays too abstract.

⸻

6. A very small “core commands only” strip

You should add one compact block containing the commands you are most likely to reach for first:

kubectl get pods
kubectl describe pod <pod>
kubectl logs <pod>
kubectl logs <pod> --previous
kubectl get svc
kubectl describe svc <service>
kubectl get endpoints <service>
kubectl get ingress
kubectl get events --sort-by=.lastTimestamp
kubectl exec -it <pod> -- sh
kubectl port-forward svc/<service> 8080:<port>

This is much more useful in an interview than a broad conceptual reminder.

⸻

7. Explicit scope note: what is likely vs less likely

Because this is for an application platform engineer interview, the visual should bias toward what is most likely:
	•	pod startup/crash
	•	probes
	•	config/secret/env
	•	service selector/port/endpoints
	•	ingress path/backend
	•	dependency connectivity
	•	DNS / namespace mistakes
	•	maybe RBAC / NetworkPolicy

And de-emphasise:
	•	deep scheduler theory
	•	obscure storage edge cases
	•	highly advanced controller internals

Not remove them entirely, just visually subordinate them.

⸻

8. A “default triage loop” box

Something like:

Default triage loop
	1.	kubectl get pods
	2.	if pod unhealthy → describe pod, logs, previous logs
	3.	if pod healthy → check service + endpoints
	4.	if service works internally → check ingress/external route
	5.	if app still fails → inspect dependency path
	6.	make one fix
	7.	verify end to end

That gives you a fallback even when the symptom is unclear.

⸻

