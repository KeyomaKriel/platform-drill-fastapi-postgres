# Scenario 02 - Network Policies

**Date/Time:** 2026-04-05 ~15:08-15:44 BST

## Symptom Presented

"The API was working a minute ago but now requests to the app are timing out. Nothing was deployed recently that they know of."

## What Was Actually Broken

The `allow-app-from-ingress` NetworkPolicy's podSelector was changed from `app=platform-drill-api` to `app=platform-drill-api-v2`. Combined with the `default-deny-ingress` policy, this silently dropped all traffic from the ingress-nginx namespace to the app pods. Pods appeared healthy but external requests timed out.

## Failure Domain

Network policies

## Fix Succeeded

Yes. User edited the NetworkPolicy to correct the podSelector back to `app=platform-drill-api`.

## Evaluation

| Priority | Rating | Notes |
|---|---|---|
| Orientation | Strong | Full universal triage: context, pods, deploy, svc, ingress, events, then `get all`. Systematic and thorough. |
| Intentional commands | Strong | Each command had a clear purpose. Endpoints check and port-forward were the key isolation steps, both done deliberately. |
| Hypothesis-driven | Solid | Good progression: healthy pods + working port-forward = problem between Ingress and app. Checked NetworkPolicies next. Could have verbalized hypothesis more explicitly before jumping in. |
| One fix at a time | Strong | Single edit to one NetworkPolicy. Clean. |
| End-to-end verification | Strong | Hit all three endpoints (/, /health, /items) via curl through Ingress. Also verified pods and re-checked the policy list. Big improvement from scenario 1. |
| Communication | Needs Work | This was a coached scenario, so narration wasn't tested independently. Practice saying the reasoning chain out loud without prompting. |

## Notable Good Commands

- `kubectl get endpoints` — immediately checked Service routing
- `kubectl port-forward svc/platform-drill-api 8080:80` — isolated problem to Ingress/network layer
- `kubectl get networkpolicy` — podSelector mismatch visible in listing output
- `kubectl describe networkpolicy allow-app-from-ingress` — confirmed the broken field
- Full curl verification on all three endpoints at the end

## Unnecessary/Redundant Commands

- `kubectl exec ... curl` — failed because curl isn't in the image. Not wrong to try but don't spend time on it in an interview when host-level curl is available
- `kubectl describe ingress app-ingress` — by this point the NetworkPolicy was already identified as the issue; committing to the theory sooner would save time

## Suggested Narration

- After port-forward succeeds: "The Service routes to the pod correctly — I get a 200 through port-forward. So the problem is upstream of the Service. Either the Ingress config is wrong or something is blocking traffic between Ingress and the app."
- After seeing the NetworkPolicy list: "The allow-app-from-ingress policy has podSelector app=platform-drill-api-v2 but my pods are labeled app=platform-drill-api. This allow rule isn't matching any pods, so the default-deny is blocking ingress traffic. That's my root cause."
- After fixing: "I've corrected the podSelector. Now let me verify end-to-end through the Ingress — not just that pods are running, but that external curl actually returns valid responses."
