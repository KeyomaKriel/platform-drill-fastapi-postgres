Fallback loop
	1.	kubectl get pods -n <ns>
	2.	If a pod looks bad: kubectl describe pod <pod> -n <ns> and kubectl logs <pod> -n <ns> --previous
	3.	If pods look healthy: kubectl get svc -n <ns> and kubectl get endpoints <svc> -n <ns>
	4.	If service looks fine but external path fails: kubectl get ingress -n <ns> and kubectl describe ingress <ing>
	5.	If app is up but feature fails: check logs, env, and dependency reachability

Memorise only this spoken frame:

“I’m going to check the workload first, then the traffic path, then dependencies. So first I’ll look at pods and see whether this is a startup or readiness problem. If the pods are healthy, I’ll move to service and endpoints. If that looks fine, I’ll check ingress or the external path.”

That is interview-grade. It sounds structured, and it is.

If they say no, do this immediately:
“I’ve closed it. I’ll work directly from the cluster state and talk through my reasoning.”

That makes you look calm, not underprepared.

And stop trying to remember the whole document now. That is the wrong move with one hour left. Burn in just these command groups:

kubectl get pods -n <ns>

kubectl describe pod <pod> -n <ns>

kubectl logs <pod> -n <ns> --previous

kubectl get svc -n <ns>

kubectl get endpoints <svc> -n <ns>

kubectl get ingress -n <ns>

Then keep these symptom mappings in your head:

CrashLoopBackOff or restarts -> logs and describe pod

Running but not Ready -> describe pod, think readiness probe

Service failing -> endpoints and service selector

External route failing -> ingress

Feature failing but app is up -> dependency/config/DNS