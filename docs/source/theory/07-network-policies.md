# What NetworkPolicies Actually Block

NetworkPolicies are Kubernetes' firewall rules at the pod level. They control which pods can talk to which other pods, and which external traffic can reach pods.

## The default: everything is allowed

With no NetworkPolicies, all pods can talk to all other pods and all external traffic can reach any pod. NetworkPolicies are additive restrictions — they only reduce what's allowed.

## How they work

A NetworkPolicy has three parts:

1. **podSelector**: which pods this policy applies to. `podSelector: {}` (empty) means all pods in the namespace.
2. **policyTypes**: `Ingress` (inbound), `Egress` (outbound), or both.
3. **ingress/egress rules**: what traffic IS allowed. Everything not explicitly allowed is denied.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: drill
spec:
  podSelector: {}          # applies to ALL pods in namespace
  policyTypes:
    - Ingress              # controls inbound traffic
  # no ingress rules = deny ALL inbound traffic
```

This single policy denies all inbound traffic to every pod in the namespace. Nothing can reach the app unless another policy explicitly allows it.

## The default-deny + explicit-allow pattern

In a well-configured namespace, you'll typically see:

1. **default-deny-ingress** — blocks all inbound by default
2. **allow-app-from-ingress** — allows the ingress controller to reach the app pods
3. **allow-postgres-from-app** — allows app pods to reach the database
4. **allow-dns** — allows all pods to reach CoreDNS for name resolution

If any of these allow rules is missing or misconfigured, traffic silently fails.

## What "silently" means

NetworkPolicy blocks don't produce error messages. There's no "connection refused" — the packets just never arrive. You see:
- Timeouts with no response
- Connections that hang forever
- No error logs on either side

This is why NetworkPolicy is typically the last thing you check — it's invisible until you know to look for it.

## What breaks

| Missing/broken rule | Effect |
|---|---|
| No allow rule for ingress-controller → app | External traffic times out; port-forward to service may also fail depending on policy scope |
| No allow rule for app → database | App can't connect to database; crashes or returns 5xx |
| No DNS egress rule | Pods can't resolve ANY hostnames — all DNS lookups fail silently |
| Wrong `podSelector` in allow rule | Rule exists but doesn't match the right pods (label typo) |
| Wrong `namespaceSelector` | Rule allows traffic from wrong namespace — ingress-nginx traffic still blocked |

## The DNS egress trap

This is the most subtle NetworkPolicy failure. If you have a default-deny policy that includes `Egress`, and no explicit rule allowing UDP port 53 to the `kube-system` namespace, pods cannot resolve any hostnames. This breaks everything — the app can't find the database, can't reach any service by name. And the error is just a timeout or `Name or service not known`, which looks like a DNS problem, not a policy problem.

## Debugging approach

1. `kubectl get networkpolicy -n <ns>` — are there any policies?
2. `kubectl describe networkpolicy -n <ns>` — read the selectors and rules
3. Compare pod labels (`kubectl get pods --show-labels`) against policy selectors
4. In an interview/sandbox: temporarily delete a suspect policy and test. If traffic works, that was the blocker. Re-apply a corrected version.

## Key mental model

NetworkPolicies answer one question: "Is this traffic flow explicitly allowed?" If the answer is no — either because there's no allow rule, or the allow rule doesn't match the right pods/namespaces — the traffic silently disappears. When everything looks right but nothing works, check the policies.
