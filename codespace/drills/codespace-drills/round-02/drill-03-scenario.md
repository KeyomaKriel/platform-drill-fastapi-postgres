# Drill 03 — Debugging (Django App)

## App

Django incident management API (`drill-app-django`), namespace `incident-mgmt`.

## Setup

App is already deployed and healthy in the Codespace.

Verify before injecting:

```
curl localhost/api/v1/status
curl localhost/api/v1/incidents
```

Both should return 200.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvcmVhZGluZXNzUHJvYmUvaHR0cEdldC9wYXRoIiwidmFsdWUiOiIvYXBpL3YxL3JlYWR5In1dJyAmJiBjbGVhcg==" | base64 -d | bash && clear
```

Wait ~30 seconds for the rollout to proceed and new pods to start failing readiness, then hand over.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "We've been getting intermittent gateway errors from the incident API over the last few minutes. It was working fine earlier. Can you figure out what's going on?"

## Timer

15 minutes.
