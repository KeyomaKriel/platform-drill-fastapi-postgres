docs/interview/k8s-troubleshooting/k8s-troubleshooting.html so that the current Fixes section is replaced by a Failure Domains section based on playbook.md.

What to do:
	•	Keep the existing HTML sections that are already good for fast interview use:
	•	Core Frame
	•	30-Second Orientation
	•	Default Triage Loop
	•	Nearest Truth Source
	•	Do Not Over-Infer
	•	Fast Symptom Map
	•	Replace the standalone Fixes section with a new Failure Domains section.
	•	Base the new section on the failure-domain model in playbook.md, not on the old fix-card model.
	•	Use the playbook’s root-cause domains as the structure. Include these domains:
	1.	Startup / Crash
	2.	Image Pull / Container Creation
	3.	Probe Failure
	4.	Config / Secret / Env
	5.	Service Routing / Port / Endpoint
	6.	DNS / Service Discovery / Namespace
	7.	Resource / Scheduling / Storage
	8.	Ingress / External Routing
	9.	NetworkPolicy / Traffic Restriction
	10.	RBAC / Service Account / Permission
	11.	Application-Level Dependency / Runtime

	•	Keep the HTML’s current visual style and interaction pattern consistent with the rest of the page.
	•	Update symptom cards so they link to the relevant failure domain anchors instead of old fix anchors.

Important:
	•	Do not remove the symptom-first flow.
	•	The page should still work as: symptom map → failure domain → commands / interpretation / fix / verify.