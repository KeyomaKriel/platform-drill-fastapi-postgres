Update `k8s-troubleshooting.html` to improve the interview narration only.

Goal:
Make the narration better aligned to a Platform Engineer / “platform as product” interview without turning it into abstract theory. Keep it practical, technical, and usable live in an interview.

What to change:
1. Review all narration text, especially:
   - `.say-block` text in symptom cards
   - `.say-block` text in failure domain cards
   - any explanatory narration around verification
2. Update the narration so it sounds like something I could actually say out loud in the interview.
3. Add a light layer of platform judgment where it helps:
   - mention developer impact when relevant
   - mention config/contracts/defaults/guardrails/debuggability when relevant
   - prefer durable repo/source-of-truth fixes over one-off cluster pokes when relevant
   - mention verification of the user-visible path where relevant
4. Do NOT add fluffy product language, leadership language, or generic platform philosophy.

Specific guidance:
- Symptom card `say-block`s:
  Most of them are technically sound already, but some could add a brief “why this matters operationally” angle.
- Failure domain `say-block`s:
  These can include a second sentence when useful, especially to show:
  - why the issue matters to developers/users of the platform
  - why the durable fix belongs in manifests/repo/config rather than ad hoc cluster state
  - why signalling/guardrails could have made the issue easier to catch
- Verification section:
  Make sure the wording reflects full verification and durable correction, not just “pod is running.”

For example, instead of:
	•	“The pod looks fine, so the break is between the Service and the Pod. I want endpoints first to see if the Service selector matches.”

make it:
	•	“The pod looks fine, so the break is between the Service and the Pod. I want endpoints first to see whether this is a selector or port contract issue, because that’s the kind of mismatch that makes a deployment look healthy while still failing for developers.”  ￼

That is better because it still sounds natural in an interview, but it now shows:
	•	you understand the failure domain
	•	you understand the user impact
	•	you think in terms of contracts and debuggability

After editing, also provide a short summary of:
1. what kinds of narration changes you made
2. where you intentionally kept the wording as-is because it was already good