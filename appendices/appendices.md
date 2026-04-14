<a id="appendix-linux"></a>
## Appendix A: Linux / Bash / Zsh Commands

---

| Command | What it does | Example |
|---|---|---|
| `grep "pattern" file` | Search for pattern in file | `grep "error" app.log` |
| `grep -r "pattern" dir/` | Recursive search in directory | `grep -r "POSTGRES" ./manifests/` |
| `grep -i "pattern" file` | Case-insensitive search | `grep -i "crashloop" events.txt` |
| `grep -c "pattern" file` | Count matching lines | `grep -c "200" access.log` |
| `cat file` | Print file contents | `cat /etc/resolv.conf` |
| `less file` | Page through file (q to quit) | `less app.log` |
| `head -n 20 file` | Print first N lines | `head -n 20 startup.log` |
| `tail -n 50 file` | Print last N lines | `tail -n 50 app.log` |
| `tail -f file` | Follow file in real time | `tail -f <ns>-session.log` |
| `wc -l file` | Count lines in file | `wc -l app.log` |
| `awk '{print $3}' file` | Print Nth column | `kubectl get pods \| awk '{print $1}'` |
| `cut -d',' -f2 file` | Cut field by delimiter | `cut -d':' -f2 /etc/passwd` |
| `sort file` | Sort lines alphabetically | `sort namespaces.txt` |
| `uniq file` | Remove consecutive duplicates | `sort errors.txt \| uniq` |
| `sort \| uniq -c` | Count occurrences of each unique line | `cat events.txt \| sort \| uniq -c` |
| `xargs` | Pass stdin as arguments to a command | `kubectl get pods \| awk '{print $1}' \| xargs kubectl describe pod` |
| `watch -n 2 cmd` | Re-run command every N seconds | `watch -n 2 kubectl get pods -n <ns>` |
| `env` | Print all environment variables | `env \| grep POSTGRES` |
| `export VAR=val` | Set env var for current session | `export KUBECONFIG=~/.kube/config` |
| `echo "string"` | Print string to stdout | `echo $POSTGRES_HOST` |
| `curl -s URL` | Silent HTTP request (no progress) | `curl -s localhost/health` |
| `curl -o /dev/null -w '%{http_code}' URL` | Print only HTTP status code | `curl -s -o /dev/null -w '%{http_code}' localhost/` |
| `curl -H "Header: val" URL` | Send custom header | `curl -H "Host: myapp.local" localhost/health` |
| `curl --max-time 5 URL` | Fail after N seconds | `curl --max-time 5 localhost/health` |
| `curl -i URL` | Include response headers in output | `curl -i localhost/health` |
| `wget -qO- URL` | Fetch URL to stdout, quiet | `wget -qO- localhost/health` |
| `jq '.key'` | Extract key from JSON | `kubectl get pod app -o json \| jq '.status.phase'` |
| `jq -r '.key'` | Raw string output (no quotes) | `kubectl get secret s -o json \| jq -r '.data.password'` |
| `base64 -d <<< "string"` | Decode base64 (Linux) | `echo "cGFzcw==" \| base64 -d` |
| `base64 -D <<< "string"` | Decode base64 (macOS) | `echo "cGFzcw==" \| base64 -D` |
| `nc -z host port` | Test TCP reachability (no data) | `nc -z postgres 5432` |
| `dig hostname` | DNS lookup with full response | `dig postgres.<ns>.svc.cluster.local` |
| `nslookup hostname` | Simple DNS lookup | `nslookup postgres` |
| `ps aux` | List all running processes | `ps aux \| grep python` |
| `kill -9 PID` | Force-kill process by PID | `kill -9 1234` |

---

<a id="appendix-kubectl"></a>
## Appendix B: kubectl Commands

---

| Command | Purpose |
|---|---|
| **Read** | |
| `kubectl config current-context` | Show active cluster context |
| `kubectl config use-context <ctx>` | Switch cluster context |
| `kubectl config view --minify` | Show active context config only |
| `kubectl config set-context --current --namespace=<ns>` | Set default namespace |
| `kubectl get ns` | List all namespaces |
| `kubectl get all -n <ns>` | List pods, deploys, services, replicasets in namespace |
| `kubectl get all -A` | List all resources across all namespaces |
| `kubectl get pods -n <ns> -o wide` | Pods with node and IP info |
| `kubectl get pods -n <ns> --show-labels` | Pods with their labels |
| `kubectl get pods -n <ns> -w` | Watch pod status in real time |
| `kubectl get deploy -n <ns>` | List Deployments |
| `kubectl get svc -n <ns>` | List Services |
| `kubectl get endpoints -n <ns>` | List Endpoints (check if populated) |
| `kubectl get ingress -n <ns>` | List Ingress resources |
| `kubectl get pvc -n <ns>` | List PersistentVolumeClaims |
| `kubectl get pv` | List PersistentVolumes (cluster-scoped) |
| `kubectl get sc` | List StorageClasses |
| `kubectl get configmap -n <ns>` | List ConfigMaps |
| `kubectl get secret -n <ns>` | List Secrets |
| `kubectl get networkpolicy -n <ns>` | List NetworkPolicies |
| `kubectl get sa -n <ns>` | List ServiceAccounts |
| `kubectl get role,rolebinding -n <ns>` | List RBAC Role and RoleBinding |
| `kubectl get rs -n <ns>` | List ReplicaSets |
| `kubectl get jobs -n <ns>` | List Jobs |
| `kubectl get cronjobs -n <ns>` | List CronJobs |
| `kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp` | Events sorted by time |
| `kubectl get pod <pod> -n <ns> -o yaml` | Full pod spec as YAML |
| `kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[*].image}'` | Extract specific field via jsonpath |
| `kubectl api-resources` | List all resource types and short names |
| `kubectl explain pod.spec.containers` | Show schema docs for a resource field |
| **Diagnose** | |
| `kubectl describe pod <pod> -n <ns>` | Full pod state, events, probe status |
| `kubectl describe svc <svc> -n <ns>` | Service selector, endpoints, ports |
| `kubectl describe deploy <deploy> -n <ns>` | Deployment state, strategy, conditions |
| `kubectl describe ingress <ingress> -n <ns>` | Ingress rules, backend, address |
| `kubectl describe pvc <pvc> -n <ns>` | PVC binding status and events |
| `kubectl describe node <node>` | Node capacity, allocatable, taints, conditions |
| `kubectl logs <pod> -n <ns>` | Container stdout/stderr |
| `kubectl logs <pod> -n <ns> --previous` | Logs from last crashed container |
| `kubectl logs <pod> -n <ns> -c <container>` | Logs from specific container (init containers) |
| `kubectl logs <pod> -n <ns> --tail=50` | Last 50 lines of logs |
| `kubectl logs <pod> -n <ns> -f` | Stream logs in real time |
| `kubectl top nodes` | Node CPU/memory usage |
| `kubectl top pods -n <ns>` | Pod CPU/memory usage |
| `kubectl auth can-i <verb> <resource> -n <ns> --as=system:serviceaccount:<ns>:<sa>` | Check RBAC permission for a ServiceAccount |
| `kubectl rollout status deploy/<deploy> -n <ns>` | Show rollout progress |
| `kubectl rollout history deploy/<deploy> -n <ns>` | List rollout revision history |
| **Fix** | |
| `kubectl apply -f <file>` | Apply manifest (create or update) |
| `kubectl edit <resource> <name> -n <ns>` | Edit resource live in $EDITOR |
| `kubectl patch <resource> <name> -n <ns> -p '<json>'` | Inline patch resource |
| `kubectl set image deploy/<deploy> <container>=<image> -n <ns>` | Update container image |
| `kubectl rollout undo deploy/<deploy> -n <ns>` | Roll back to previous revision |
| `kubectl rollout restart deploy/<deploy> -n <ns>` | Restart all pods in a deployment |
| `kubectl scale deploy/<deploy> --replicas=<n> -n <ns>` | Change replica count |
| `kubectl delete pod <pod> -n <ns>` | Force pod recreation |
| `kubectl delete <resource> <name> -n <ns>` | Delete any resource |
| `kubectl create configmap <name> --from-literal=KEY=val -n <ns>` | Create ConfigMap from literals |
| `kubectl create secret generic <name> --from-literal=KEY=val -n <ns>` | Create Secret from literals |
| `kubectl create rolebinding <name> --role=<role> --serviceaccount=<ns>:<sa> -n <ns>` | Create RoleBinding |
| `kubectl create job <name> --from=cronjob/<cj> -n <ns>` | Trigger CronJob manually |
| **Debug/Test** | |
| `kubectl exec <pod> -n <ns> -- env` | Print env vars inside container |
| `kubectl exec -it <pod> -n <ns> -- sh` | Interactive shell in container |
| `kubectl exec <pod> -n <ns> -- wget -qO- http://svc/health` | Test HTTP from inside the cluster |
| `kubectl exec <pod> -n <ns> -- nc -z <host> <port>` | Test TCP reachability from inside pod |
| `kubectl port-forward pod/<pod> 8080:8000 -n <ns>` | Forward pod port to localhost |
| `kubectl port-forward svc/<svc> 8080:80 -n <ns>` | Forward service port to localhost |

---

<a id="appendix-git"></a>
## Appendix C: Git Commands

---

| Command | Purpose |
|---|---|
| `git status` | Show changed, staged, and untracked files |
| `git diff` | Show unstaged changes |
| `git diff --staged` | Show staged changes (what will be committed) |
| `git log --oneline` | Compact commit history |
| `git log -p` | Commit history with diffs |
| `git checkout <branch>` | Switch to existing branch |
| `git checkout -b <branch>` | Create and switch to new branch |
| `git add <file>` | Stage specific file |
| `git commit -m "message"` | Commit staged changes |
| `git commit --amend` | Amend most recent commit |
| `git stash` | Temporarily shelve uncommitted changes |
| `git stash pop` | Restore most recently stashed changes |
| `git reset --soft HEAD~1` | Undo last commit, keep changes staged |
| `git reset --hard HEAD~1` | **Destructive.** Undo last commit and discard all changes |
| `git branch` | List local branches |
| `git branch -d <branch>` | Delete merged local branch |
| `git cherry-pick <sha>` | Apply a specific commit to current branch |
| `git blame <file>` | Show who last changed each line |

---

<a id="appendix-http"></a>
## Appendix D: HTTP Status Codes

---

| Code | Meaning | Kubernetes / Interview Context |
|---|---|---|
| 200 | OK | Expected response from healthy endpoints. |
| 301 | Moved Permanently | Permanent redirect. May appear from nginx Ingress path rewrites. → [Bucket E](#bucket-e) |
| 302 | Found (Temporary Redirect) | Temporary redirect. Check Ingress path rules or app-level redirects. → [Bucket E](#bucket-e) |
| 400 | Bad Request | Malformed request. Usually app-level — check request format, not K8s config. → [Bucket H](#bucket-h) |
| 401 | Unauthorized | Authentication missing or invalid. Check auth headers, tokens, or ServiceAccount. → [Bucket A](#bucket-a) |
| 403 | Forbidden | Authenticated but not permitted. Check RBAC Role/RoleBinding, `kubectl auth can-i`. → [Bucket A](#bucket-a) |
| 404 | Not Found | Route doesn't exist. → [Readiness probe](#sub-readiness) (if probe path wrong) · [Bucket E](#bucket-e) (if Ingress path wrong) |
| 408 | Request Timeout | Client timed out waiting. Check app logs, Ingress timeout config. → [Bucket H](#bucket-h) · [Bucket E](#bucket-e) |
| 429 | Too Many Requests | Rate limited. Check Ingress rate-limit annotations or API gateway config. → [Bucket E](#bucket-e) |
| 500 | Internal Server Error | App crashed processing request. Check pod logs for stack trace. → [Bucket H](#bucket-h) |
| 502 | Bad Gateway | Proxy received invalid response from upstream. Check endpoints, pod readiness, targetPort. → [Bucket D](#bucket-d) · [Bucket E](#bucket-e) |
| 503 | Service Unavailable | No healthy backend. Check pod readiness, service selector, endpoints, backend port. → [Bucket D](#bucket-d) · [Bucket E](#bucket-e) |
| 504 | Gateway Timeout | Proxy timed out waiting for upstream. Check app performance, resource limits, Ingress timeout. → [Bucket H](#bucket-h) · [Bucket E](#bucket-e) |

---

<a id="appendix-exit-codes"></a>
## Appendix E: Exit Codes, Pod Statuses, and Error Reasons

---

### Container Exit Codes

| Code | Meaning | Typical Cause | Next Step |
|---|---|---|---|
| 0 | Success | Container completed normally | Expected for init containers and [Jobs](#bucket-g). If unexpected for a long-running app, check command/args. |
| 1 | Generic application error | Unhandled exception, config error, bad startup | `kubectl logs <pod> --previous` → [CrashLoop sub-branch](#sub-crashloop) |
| 2 | Misuse of shell builtins | Bad shell command in `command` or `args` | Check pod spec `command`/`args` syntax → [CrashLoop sub-branch](#sub-crashloop) |
| 3 | Application-defined exit | App uses code 3 for specific error (e.g., Python/uvicorn unhandled exception) | Check app logs → [CrashLoop sub-branch](#sub-crashloop) |
| 126 | Command not executable | Script/binary not executable | Check file permissions inside the image → [CrashLoop sub-branch](#sub-crashloop) |
| 127 | Command not found | Binary missing from container image | Verify image contents with `kubectl exec` → [CrashLoop sub-branch](#sub-crashloop) |
| 128 | Invalid argument to exit | Shell received signal or invalid exit call | Check entrypoint/cmd scripting → [CrashLoop sub-branch](#sub-crashloop) |
| 137 | OOMKilled (128 + 9) | Container exceeded memory limit | `kubectl describe pod` last state; increase memory limit → [CrashLoop sub-branch](#sub-crashloop) |
| 139 | Segfault (128 + 11) | Memory access violation | Application bug or corrupted binary → [CrashLoop sub-branch](#sub-crashloop) |
| 143 | Graceful SIGTERM (128 + 15) | Normal shutdown, preStop hook, or pod deletion | Usually expected. If unexpected, check [liveness probe](#sub-liveness). |

---

### Pod Status Reasons

| Status | Meaning | Next Step |
|---|---|---|
| Running | Containers started, at least one still running | Check Ready column — Running but 0/1 → [Readiness sub-branch](#sub-readiness) |
| Pending | Pod accepted but not scheduled or containers not started | `kubectl describe pod` — look for FailedScheduling → [Pending sub-branch](#sub-pending) |
| CrashLoopBackOff | Container keeps crashing, K8s backing off restarts | `kubectl logs <pod> --previous` → [CrashLoop sub-branch](#sub-crashloop) |
| ImagePullBackOff | Repeated image pull failures | `kubectl describe pod` — check image name/tag → [ImagePull sub-branch](#sub-imagepull) |
| ErrImagePull | One-time image pull failure | Same as above → [ImagePull sub-branch](#sub-imagepull) |
| OOMKilled | Container exceeded memory limit | Increase memory limit; `kubectl describe pod` last state → [CrashLoop sub-branch](#sub-crashloop) |
| Error | Container exited with non-zero code | `kubectl logs <pod> --previous` — check exit code → [CrashLoop sub-branch](#sub-crashloop) |
| Init:CrashLoopBackOff | Init container crashing | `kubectl logs <pod> -c <init-container>` → [Init container sub-branch](#sub-init) |
| Init:0/1 | Init container not yet completed | `kubectl logs <pod> -c <init-container>` — may be waiting on dependency → [Init container sub-branch](#sub-init) |
| Completed | All containers exited with 0 | Normal for [Jobs](#bucket-g). Unexpected for Deployments — check restart policy |
| Terminating | Pod being deleted | Check for stuck finalizers; may need force delete |
| Unknown | Node unreachable | Check node health — `kubectl get nodes`, `kubectl describe node` |
| ContainerCreating | Image pulling or volume mounting | If stuck: `kubectl describe pod` for mount/pull events → [Bucket J](#bucket-j) |
| PodInitializing | Init containers running | Normal — check init container logs if stuck → [Init container sub-branch](#sub-init) |

---

### Common Event Reasons

| Reason | Meaning | Next Step |
|---|---|---|
| Scheduled | Pod assigned to node | Normal |
| Pulled | Image pulled from registry | Normal |
| Created | Container created | Normal |
| Started | Container started | Normal |
| Killing | Container being killed | If unexpected: check [liveness probe](#sub-liveness) config |
| BackOff | Backing off restart or pull | → [CrashLoop sub-branch](#sub-crashloop) or [ImagePull sub-branch](#sub-imagepull) |
| FailedScheduling | No suitable node found | `kubectl describe pod` — insufficient CPU/memory, taints → [Pending sub-branch](#sub-pending) · [Bucket J](#bucket-j) |
| FailedMount | Volume could not be mounted | Check PVC name, StorageClass, mount path → [Bucket F](#bucket-f) · [Bucket J](#bucket-j) |
| FailedAttachVolume | PVC exists but can't attach to node | Check PVC bound status, provisioner → [Bucket J](#bucket-j) |
| Unhealthy | Readiness or liveness probe failed | `kubectl describe pod` shows which probe → [Readiness](#sub-readiness) · [Liveness](#sub-liveness) |
| FailedCreate | ReplicaSet couldn't create pod | `kubectl describe rs` — quota or invalid spec → [Bucket C](#bucket-c) |
| SuccessfulCreate | Pod created by ReplicaSet | Normal |
| SuccessfulDelete | Pod deleted during scale-down/rollout | Normal |
| RELOAD | nginx Ingress controller reloaded config | Normal — happens when Ingress resources change |
| Sync | Ingress controller synced state | Normal |
| Forbidden | RBAC denied an action | `kubectl auth can-i` → [Bucket A](#bucket-a) |
| Evicted | Pod evicted due to resource pressure | `kubectl describe node` → [Pending sub-branch](#sub-pending) |
| NodeNotReady | Pod's node entered NotReady state | `kubectl get nodes`, `kubectl describe node` |
| InsufficientMemory | Node lacks memory to schedule pod | Reduce memory request → [Pending sub-branch](#sub-pending) |
| InsufficientCPU | Node lacks CPU to schedule pod | Reduce CPU request → [Pending sub-branch](#sub-pending) |