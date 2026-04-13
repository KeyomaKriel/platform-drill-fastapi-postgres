# Drill 01 — Debugging (Config / Secret / Env)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvZW52RnJvbS8xL3NlY3JldFJlZi9uYW1lIiwidmFsdWUiOiJpbmNpZGVudC1hcGktc2VjcmV0cyJ9LHsib3AiOiJyZXBsYWNlIiwicGF0aCI6Ii9zcGVjL3RlbXBsYXRlL3NwZWMvaW5pdENvbnRhaW5lcnMvMS9lbnZGcm9tLzEvc2VjcmV0UmVmL25hbWUiLCJ2YWx1ZSI6ImluY2lkZW50LWFwaS1zZWNyZXRzIn1dJyAmJiBjbGVhcgo=" | base64 -d | bash && clear
```

Wait ~15 seconds for the rollout to begin, then hand over.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API just went down after a deployment change. Users are reporting it's completely unreachable. Can you take a look?"

## Timer

15 minutes.
