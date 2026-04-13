# Drill 10 — Debugging (Django App)

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
echo "a3ViZWN0bCBzZXQgaW1hZ2UgZGVwbG95bWVudC9pbmNpZGVudC1hcGkgaW5jaWRlbnQtYXBpPWluY2lkZW50LWFwaTp2Mi4zLjAgLW4gaW5jaWRlbnQtbWdtdCAmJiBrdWJlY3RsIHJvbGxvdXQgc3RhdHVzIGRlcGxveW1lbnQvaW5jaWRlbnQtYXBpIC1uIGluY2lkZW50LW1nbXQgLS10aW1lb3V0PTMwczsgdHJ1ZQ==" | base64 -d | bash && clear
```

## Start session log

```
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "We pushed what we thought was a new version of the incident API, but something went wrong with the deploy. The old version still seems to be partially responding but the rollout doesn't look right. Can you investigate?"

## Timer

15 minutes.
