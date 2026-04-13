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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvcmVhZGluZXNzUHJvYmUvaHR0cEdldC9wYXRoIiwidmFsdWUiOiIvaGVhbHRoIn0seyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvbGl2ZW5lc3NQcm9iZS9odHRwR2V0L3BhdGgiLCJ2YWx1ZSI6Ii9oZWFsdGgifV0n" | base64 -d | bash && clear
```

## Start session log

```
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API seems to be flapping — it works for a bit then stops, then comes back. Users are seeing intermittent errors. Can you take a look?"

## Timer

15 minutes.
