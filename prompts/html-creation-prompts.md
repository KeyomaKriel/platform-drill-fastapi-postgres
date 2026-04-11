look at k8s-troubleshooting.md
I want an .html version optimized for visual interview guide but it must keep all the content.


Fix the layout in k8s-troubleshooting.html so the “Core Frame — What to Run First”
  section shows all 4 cards fully on screen on a normal desktop browser width. Right
  now the 4th card overflows to the right.

  Do not change the content. Change layout/CSS only.

  Priority order:
      1.    keep all 4 cards in one row on desktop
      2.    remove unnecessary horizontal space/waste before shrinking content
      3.    only if needed, slightly reduce Core Frame card padding/gap/font sizing
      4.    preserve the rest of the page layout as much as possible

  Do not leave any need to scroll horizontally to read the 4th card.


Done. Here's how the mapping works:

  Branch item &rarr; fix section anchor mapping

  ┌─────────────────────────────┬───────────────────────────────────────────────────┬──────────────────────────────────┐
  │        Symptom card         │                    Branch item                    │             Links to             │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Pod missing/Pending         │ scheduling/resource pressure                      │ #fix-scheduling                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ PVC/storage binding                               │ #fix-pvc                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ image pull failure                                │ #fix-image-pull                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ container creation failure                        │ #fix-config-ref                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ taints/affinity                                   │ #fix-scheduling                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ ErrImagePull                │ all 3 branches                                    │ #fix-image-pull                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ CreateContainerConfigError  │ missing Secret/ConfigMap, bad env ref, bad volume │ #fix-config-ref                  │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ bad command/args                                  │ #fix-app-startup                 │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ CrashLoopBackOff            │ config/env/secret error                           │ #fix-config-values               │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ connection refused / host not found               │ #fix-dep-connectivity + #fix-dns │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ app stack trace / boot failure                    │ #fix-app-startup                 │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ no logs + exit 137                                │ #fix-oom                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ probe-driven restart                              │ #fix-probes                      │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Running but 0/1 Ready       │ probe path/port, boot incomplete                  │ #fix-probes                      │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ dependency partial failure                        │ #fix-dep-connectivity            │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Pod healthy, Service fails  │ all 3 branches                                    │ #fix-service-selector            │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Endpoints empty             │ selector mismatch, backend wrong                  │ #fix-service-selector            │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ pods not Ready                                    │ #fix-probes                      │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ App responds, feature fails │ wrong env/secret value                            │ #fix-config-values               │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ DNS failure                                       │ #fix-dns                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ connection refused                                │ #fix-dep-connectivity            │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ RBAC                                              │ #fix-rbac                        │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ NetworkPolicy                                     │ #fix-networkpolicy               │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Init container failure      │ both branches                                     │ #fix-init-container              │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Restarts increasing         │ liveness probe                                    │ #fix-probes                      │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ intermittent crash, app error                     │ #fix-app-startup                 │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │                             │ OOM                                               │ #fix-oom                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ OOMKilled                   │ all 3 branches                                    │ #fix-oom                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ External route fails        │ all 4 branches                                    │ #fix-ingress                     │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ DNS failures                │ all 3 branches                                    │ #fix-dns                         │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Forbidden                   │ all 3 branches                                    │ #fix-rbac                        │
  ├─────────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────┤
  │ Traffic blocked             │ all 3 branches                                    │ #fix-networkpolicy               │
  └─────────────────────────────┴───────────────────────────────────────────────────┴──────────────────────────────────┘

  Fix sections shared across multiple symptoms

  - #fix-probes &larr; CrashLoopBackOff, Running 0/1 Ready, Endpoints empty (pods not Ready), Restarts increasing
  - #fix-config-values &larr; CrashLoopBackOff, App responds but feature fails
  - #fix-app-startup &larr; CreateContainerConfigError (bad command/args), CrashLoopBackOff (stack trace), Restarts increasing (intermittent crash, app error)
  - #fix-dep-connectivity &larr; CrashLoopBackOff (connection refused), Running 0/1 Ready (partial dep failure), App responds but feature fails
  - #fix-scheduling &larr; Pod missing/Pending (scheduling + taints/affinity)
  - #fix-service-selector &larr; Pod healthy Service fails, Endpoints empty
  - #fix-dns &larr; CrashLoopBackOff (host not found), App responds but feature fails, DNS failures symptom
  - #fix-oom &larr; CrashLoopBackOff (exit 137), Restarts increasing, OOMKilled symptom

  Rollout stuck and Job/CronJob route to buckets (not fix sections) since they're not root causes themselves.
