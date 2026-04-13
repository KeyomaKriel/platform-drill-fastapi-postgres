# Drill 11 — Debugging (Django App)

## Setup

The incident API (`drill-app-django`) must be deployed and healthy in the Codespace in the `incident-mgmt` namespace.

Verify before injecting:

```
curl localhost/api/v1/status
curl localhost/api/v1/incidents
```

Both should return 200.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBwYXRjaCBzdmMgaW5jaWRlbnQtYXBpLXN2YyAtbiBpbmNpZGVudC1tZ210IC1wICd7InNwZWMiOnsic2VsZWN0b3IiOnsiY29tcG9uZW50IjoiYmFja2VuZCJ9fX0n" | base64 -d | bash && clear
```

## Start session log

```
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API stopped responding to requests. The team says no deployments were made recently. Can you investigate?"

## Timer

15 minutes.
