# Troubleshooting Routing Tree — Mermaid Diagrams

Diagrams match the routing structure in `troubleshooting-routing-tree.md`.
Green nodes = root-cause domains. Yellow dotted lines = reroutes (surface symptom misleads, real cause is elsewhere).

---

## Master Flow

```mermaid
flowchart TD
    classDef domain fill:#d4edda,stroke:#28a745,color:#000

    R0(["Do not guess — start from visible symptom"])
    R0 --> N1

    N1["<b>1 · Repo-First Orientation</b><br/>App · config/env · Dockerfile<br/>K8s manifests · deploy path"]
    N1 --> N2

    N2{"<b>2 · Entry Mode?</b>"}
    N2 -->|Scope unclear| FT["Full Triage<br/>context → ns → pods -A →<br/>deploys → svcs → ingress → events"]
    N2 -->|Known app + symptom| FP["Fast Path<br/>pods → describe → logs →<br/>reachability layer by layer"]
    FT --> N3
    FP --> N3

    N3{"<b>3 · Pod State?</b><br/>STATUS · READY · RESTARTS"}
    N3 -->|Not healthy| N4[["→ Pod Symptom<br/>Classification"]]
    N3 -->|Healthy| N5[["→ Reachability<br/>Path"]]
    N3 -->|No pods exist| NP{"Deploy exists?<br/>Right namespace?"}
    NP -->|Missing / wrong ns| D_DNS["DNS / Namespace"]:::domain
    NP -->|Rollout stuck| N4

    R0 -.->|Obvious direct symptom| N6[["→ Special<br/>Entry Points"]]

    N4 --> FIX
    N5 --> FIX
    N6 --> FIX
    D_DNS --> FIX

    FIX["<b>7 · Smallest Justified Fix</b><br/>One change · one reason · correct deploy path"]
    FIX --> V

    V{"<b>8 · End-to-End Verification</b><br/>pods → endpoints → pod curl<br/>→ svc curl → ingress curl → app response"}
    V -->|All pass| DONE(["Done"])
    V -->|Any fail| N3
```

---

## Pod Symptom Classification (Node 4 + 4a)

CrashLoopBackOff is a **symptom hub** — logs decide the real root-cause branch.

```mermaid
flowchart TD
    classDef domain fill:#d4edda,stroke:#28a745,color:#000
    classDef reroute fill:#fff3cd,stroke:#e6a800,color:#000

    SYM{"Pod Symptom"}

    SYM -->|"ImagePullBackOff<br/>ErrImagePull"| D_IMG["Image Pull /<br/>Container Creation"]:::domain

    SYM -->|"CreateContainer<br/>ConfigError"| D_CRE["Image Pull /<br/>Container Creation"]:::domain
    D_CRE -.->|often missing<br/>ConfigMap/Secret ref| R_CFG["Config / Secret / Env"]:::reroute

    SYM -->|Pending| D_RES["Resource /<br/>Scheduling / Storage"]:::domain

    SYM -->|"Running but 0/1"| D_PRB["Probe Failure<br/>(readiness)"]:::domain
    D_PRB -.->|probe correct but<br/>app unhealthy| R_APP["App-Level"]:::reroute

    SYM -->|"Running + Ready<br/>restarts climbing"| D_LIV["Probe Failure<br/>(liveness)"]:::domain

    SYM -->|"CrashLoopBackOff<br/>Error · Init:CrashLoop"| HUB

    HUB["<b>Symptom Hub</b><br/>describe · logs · logs --previous"]
    HUB --> LOGS

    LOGS{"What do logs say?"}

    LOGS -->|"Missing ConfigMap /<br/>Secret / key ref"| L_CFG["Config / Secret / Env"]:::domain
    LOGS -->|"Wrong env value<br/>(host, DB, password)"| L_CFG2["Config / Secret / Env"]:::domain
    LOGS -->|"Name or service<br/>not known"| L_DNS["DNS / Namespace"]:::domain
    L_DNS -.->|hostname value<br/>itself is wrong| L_CFG
    LOGS -->|"Connection refused /<br/>timed out"| L_APP["App-Level<br/>Dependency"]:::domain
    L_APP -.->|host/port value<br/>is wrong| L_CFG
    LOGS -->|"Auth failure<br/>to dependency"| L_AUTH["Config / Secret / Env"]:::domain
    LOGS -->|"OOMKilled /<br/>exit 137"| L_RES["Resource /<br/>Scheduling / Storage"]:::domain
    LOGS -->|"App error /<br/>exception"| L_CRA["Startup / Crash"]:::domain
    LOGS -->|"Command not found /<br/>exec format error"| L_IMG["Image Pull /<br/>Container Creation"]:::domain
    LOGS -->|"Starts then killed<br/>by probes"| L_PRB["Probe Failure"]:::domain
    LOGS -->|"Forbidden on<br/>K8s API call"| L_RBAC["RBAC /<br/>Service Account"]:::domain
```

---

## Reachability Path (Node 5)

Test layer by layer when pods are healthy. Stop at the first layer that fails.

```mermaid
flowchart TD
    classDef domain fill:#d4edda,stroke:#28a745,color:#000
    classDef reroute fill:#fff3cd,stroke:#e6a800,color:#000

    START["Pods Running + Ready"]
    START --> A

    A["<b>A · Test Pod</b><br/>port-forward pod → curl"]
    A -->|No response| D_APP["App-Level /<br/>Runtime"]:::domain
    D_APP -.->|check env vars| R_CFG["Config / Secret / Env"]:::reroute
    A -->|Responds| B

    B["<b>B · Test Service</b><br/>get endpoints → port-forward svc → curl"]
    B -->|Endpoints empty| D_SVC["Service Routing /<br/>Port / Endpoint"]:::domain
    D_SVC -.->|pods not Ready<br/>is the real reason| R_PRB["Probe Failure"]:::reroute
    B -->|Port mismatch| D_SVC2["Service Routing /<br/>Port / Endpoint"]:::domain
    B -->|Responds| C

    C["<b>C · Test Ingress</b><br/>curl localhost/"]
    C -->|"Error / wrong backend"| D_ING["Ingress /<br/>External Routing"]:::domain
    C -->|Silent timeout| D_NET["NetworkPolicy /<br/>Traffic Restriction"]:::domain
    C -->|Works| DONE(["Healthy end-to-end"])
```

---

## Special Entry Points (Node 6)

Symptoms that bypass the main pod-state → reachability flow.

```mermaid
flowchart TD
    classDef domain fill:#d4edda,stroke:#28a745,color:#000

    SYM{"Direct-route symptom?"}

    SYM -->|"Forbidden /<br/>Unauthorized"| D_RBAC["RBAC /<br/>Service Account"]:::domain
    SYM -->|Resources appear<br/>missing entirely| D_DNS["DNS / Namespace"]:::domain
    SYM -->|"PVC Pending /<br/>volume mount error"| D_RES["Resource /<br/>Scheduling / Storage"]:::domain
    SYM -->|"Pods Running + Ready<br/>but app returns 5xx"| D_APP["App-Level<br/>Dependency / Runtime"]:::domain
    SYM -->|"Deployment exists<br/>but no pods"| ROLL["Rollout stuck —<br/>check new RS pods →<br/>route through Node 4"]
```
