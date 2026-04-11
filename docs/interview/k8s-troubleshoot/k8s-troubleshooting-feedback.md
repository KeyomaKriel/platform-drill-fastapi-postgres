

What is still wrong or weak

1. It is still too long for true interview-time use

This is not an issue. I am getting Claude Code to convert the .md to html - interactive so it is just clicking to navigate

⸻

2. “Core frame — what to run first” is good, but still slightly misleading

The title says “what to run first”, but each branch assumes you already know which frame applies. In many interviews, you do not know that yet. You start with uncertain symptoms.

You partially solve that with the “Default triage loop” later, but the file still leads with branch-specific starting points.  ￼

That means the actual top priority should be the default triage loop, not the four-part branch detail.

What to change

Move this order to the top:
	1.	Rule
	2.	Default triage loop
	3.	Nearest truth source
	4.	Four-part frame
	5.	Fast symptom map

I agree with this.

⸻

3. Some commands are too placeholder-heavy to be maximally useful

There are lots of <pod>, <deploy>, <service>, <ns>, <port>, <path> placeholders. That is unavoidable to some degree, but there are too many places where the sheet gives generic commands instead of telling you how to derive the values quickly.  ￼

In an interview, the friction is often not “what command exists?” but “how do I know which pod or service to inspect right now?”

What to change

Add one tiny section near the top:

How to identify the object names quickly

kubectl get deploy -n <ns>
kubectl get pods -n <ns> -o wide
kubectl get svc -n <ns>
kubectl get ingress -n <ns>
kubectl get pods -n <ns> --show-labels

I don't really understand what you are saying here?

⸻

4. There is one important missing practical step: deployment-level inspection

You mention rollout stuck and get replicaset later, but you do not emphasize early enough that in many interview scenarios the Deployment itself is a critical truth source, not just the Pod.  ￼

Examples:
	•	wrong image in deployment
	•	wrong envFrom in deployment
	•	wrong probe in deployment
	•	wrong command override in deployment
	•	rollout not progressing
	•	selector/template-label mismatch issues

You do use kubectl get deploy in several fix sections, but the main triage flow is still too pod-centred.

What to change

In the default triage loop or core commands, add:

kubectl get deploy -n <ns>
kubectl describe deploy <deploy> -n <ns>
kubectl rollout status deploy/<deploy> -n <ns>

For this interview type, that belongs in the main body, not just in a later branch.

I agree - added in default triage.

⸻

5. “kubectl get endpoints” is useful, but you should prefer not to imply it is the whole truth forever

I don't care about this now.

⸻

6. A few branches overlap enough that they create hesitation

Shouldn't be relevant with the html
⸻

7. The verification section is good but slightly too app-specific in its examples

Don't care right now.

⸻

8. Some fix commands are a bit too “ops freehand” for a pair-programming interview

Yes, agree.

⸻

9. There are a few places where the wording can be sharpened further

A few examples:

“Pod missing, Pending, or never becomes Running”

These are not the same state family.
“Missing” means maybe wrong namespace, wrong label, wrong workload, scaling issue, or deployment not creating pods.
“Pending” means pod exists but cannot schedule or bind something.
“Never becomes Running” also includes image pull and create-container problems.

You do branch correctly beneath it, but the heading itself groups too much.  ￼

Better split
	•	No pod / expected pod missing
	•	Pod Pending
	•	Pod stuck ContainerCreating / image pull / create config error

That would be cleaner.

“What these prove”

Sometimes this is slightly too strong.
For example, “what these prove” should often be “what these usually reveal” or “what these tell me next.” In debugging, especially in interviews, avoid claiming proof where you really mean “strong signal.”  ￼

Example:
kubectl get events does not always “prove” the full reason. It often gives the best clue.

“The pod is healthy”

Be careful with that phrase.
A pod being Running and Ready means it passed Kubernetes health criteria, not that the application is truly healthy in the business sense.

You already understand that, but a few phrases could be tightened to avoid sloppy wording in the interview.

Yes, I agree.
⸻

10. You should add one explicit repo-first reminder

Don't care. Not neccessary.