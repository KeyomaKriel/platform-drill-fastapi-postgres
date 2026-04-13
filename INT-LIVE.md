## Phase 5 — Live Interview Support

**Trigger:** The user says "interview live".

**Goal:** Detect the interview Codespace, analyse the repo and cluster state, and generate two reference files the user reads on a second screen while performing the interview.

### Step 1 — Detect the interview environment

1. List all Codespaces: `gh codespace list --json name,repository,state`
2. Identify any Codespace on a repo that is NOT `KeyomaKriel/platform-drill-fastapi-postgres` — that is the interview Codespace.
3. If multiple unknown Codespaces exist, pick the one that was created most recently.
4. Store the Codespace name and repo for all subsequent steps.

### Step 2 — Analyse the repo

SSH into the interview Codespace and run:

```bash
gh codespace ssh -c <name> -- 'pwd && ls && find . -maxdepth 3 -type f | sort'
```

Then read key files in order:
- README.md (skim)
- Dockerfile
- App entry files (detect framework first: manage.py = Django, go.mod = Go, app.py/main.py = Python)
- All K8s manifests (Deployment, Service, Ingress, ConfigMap, Secret, etc.)
- Any deploy scripts

Extract:
- Framework, language, entry point
- Listening port (from CMD/startup command, not just EXPOSE)
- Health/readiness endpoints
- DB env var names
- Namespace
- Image name, pull policy
- Probe paths and ports
- Service selector and ports
- Ingress backend and routing
- Init containers
- ConfigMap/Secret names and values
- DB Service name and credentials

### Step 3 — Analyse the live cluster

```bash
gh codespace ssh -c <name> -- 'kubectl get ns && kubectl get pods -A && kubectl get svc -A && kubectl get ingress -A && kubectl get endpoints -A'
```

Then for the app namespace:
```bash
gh codespace ssh -c <name> -- 'kubectl describe pod <pod> -n <ns> && kubectl logs <pod> -n <ns> && kubectl get events -n <ns> --sort-by=.lastTimestamp'
```

Identify any faults:
- Pods not Running/Ready
- Empty endpoints
- Probe failures in Events
- Image pull errors
- Missing ConfigMap/Secret references
- Selector mismatches
- Wrong probe path/port
- Wrong Service targetPort
- Wrong Ingress backend
- CrashLoopBackOff with log errors
- Init container failures

### Step 4 — Generate two files

Save both to the drill system root (NOT inside the interview Codespace).

**File 1: `interview-orient.md`**

A step-by-step orientation script:
- What framework this is and how you recognised it
- What to say when you first look at the repo ("I'm mapping the repo structure...")
- For each key file: what it contains, what to extract, what to say
- The full contract chain (config → Service → pod labels → Ingress)
- The live check commands to run and what to say when you see the output
- A final summary narration using Shape/Start/Supply/Ship/Signals

**File 2: `interview-fix.md`**

If faults are found:
- What is broken and why
- The exact diagnostic commands to run, in order
- What each command will show
- What to say at each step (framed as hypothesis, not conclusion)
- The fix command (prefer `kubectl apply -f` from repo manifests)
- Verification commands and what to say

If no faults are found:
- State that the cluster appears healthy
- List the verification commands and expected output
- Note that a fault may be injected during the interview

**Format rules for both files:**
- Every step must have embedded narration (what to say)
- Narration must sound natural, not scripted
- Frame findings as hypotheses during diagnosis ("This suggests..." not "The problem is...")
- Include the exact kubectl commands — do not paraphrase
- Keep it scannable — the user is reading this under pressure on a second screen

### Important rules for Phase 5

- Execute as fast as possible. Every second counts.
- Run independent SSH commands in parallel where possible.
- Do not modify anything in the interview Codespace. Read-only.
- Do not create any files inside the interview Codespace.
- If the Codespace is not accessible (Shutdown, permissions), report immediately so the user can fix it.
- After generating the files, say "Ready." and nothing else.

### Re-scan trigger

**Trigger:** The user says "next bug", "scan again", "rescan", or "what now".

**Goal:** Re-analyse the live cluster state in the interview Codespace, find any new faults, and update `interview-fix.md` with the next diagnostic and fix path.

**Steps:**
1. SSH into the same interview Codespace (already identified from Phase 5 initial run).
2. Re-run the full cluster analysis from Step 3 above.
3. Compare against the previously identified fault — if it's fixed, look for new symptoms.
4. Overwrite `interview-fix.md` with the new fault analysis, commands, and narration.
5. If no new fault is found, state that the cluster appears healthy now.
6. Say "Ready." and nothing else.

This can be triggered as many times as needed. Each re-scan is a fresh analysis of current cluster state.
