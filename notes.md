Follow-up questions that may be asked.

Likely git commands (cheat sheet)

How to use AI in the interview
(get set of questions into a cheat sheet)

repo orientation should have signals commands










Yes — and the key thing is that the doc is mixing two different ideas:
	1.	the traffic path inside Kubernetes
	2.	the debug method from your laptop

That is why it felt like there were “different port-forward types between layers.”

Here is the clean version.

What is the actual traffic path?

Inside Kubernetes, the path is:

Ingress controller → Service → Pod IP → app process

And from outside:

Client → Ingress controller → Service → Pod → app

That is the real routing path.

What is kubectl port-forward doing?

kubectl port-forward is not forwarding traffic between Kubernetes layers.

It is creating a shortcut from your laptop to a chosen Kubernetes resource.

So these are not “layer-to-layer forwards.”

They are:
	•	laptop → pod
	•	laptop → service
	•	sometimes laptop → ingress controller

That is all.

Why the doc uses different port-forwards

Because each one helps you test a different layer by bypassing the layers above it.

1. Pod port-forward

kubectl port-forward pod/<pod> 8080:<app-port> -n <ns>
curl http://localhost:8080/

What this means:

your laptop → pod → app

You are bypassing Service and Ingress.

This answers:
“Does the app itself respond if I go straight to the pod?”

⸻

2. Service port-forward

kubectl port-forward svc/<service> 8080:<service-port> -n <ns>
curl http://localhost:8080/

What this means:

your laptop → Service → backend pod → app

You are bypassing Ingress, but still testing Service routing.

This answers:
“Does the Service correctly route to a working backend?”

⸻

3. Ingress test

This is where the doc is a bit loose.

When it says:

curl -i localhost/
curl -i -H "Host: <host>" localhost/

that only makes sense if you already have some way for localhost to hit the ingress controller, such as:
	•	local cluster ingress bound to localhost, or
	•	a port-forward to the ingress controller service, or
	•	some local host mapping

A more explicit version would be:

kubectl port-forward svc/ingress-nginx-controller 8080:80 -n ingress-nginx
curl -i -H "Host: <host>" http://localhost:8080/

What this means:

your laptop → ingress controller → Service → pod → app

That answers:
“Does ingress routing work?”

⸻

So the debug method is:

If pod forward works

The app is probably listening and responding.

If pod forward works but service forward fails

The problem is probably in:
	•	selector
	•	endpoints
	•	targetPort/service port mismatch
	•	readiness preventing endpoints

If service forward works but ingress test fails

The problem is probably in:
	•	ingress host rule
	•	path rule
	•	backend service name
	•	backend service port
	•	ingressClass/controller

That is the whole point of the different commands.

The most important conceptual fix

Do not think:

“container to pod, pod to service, service to ingress”

Think:

“I am choosing where to enter the chain from my laptop.”

You are selecting a test entry point:
	•	enter at pod
	•	enter at service
	•	enter at ingress

And each one tells you whether that layer and everything below it works.

Best mental model

Real system path

client → ingress → service → pod → app

Debug shortcuts
	•	laptop → pod to test app directly
	•	laptop → service to test service routing
	•	laptop → ingress controller to test ingress routing

That is the cleanest way to understand it.

Your confusion made sense because the doc describes the real routing chain and the debug shortcut method in the same section. That is exactly where people get mixed up.