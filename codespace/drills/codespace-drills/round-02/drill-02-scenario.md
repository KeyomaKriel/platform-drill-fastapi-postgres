# Drill 02 — Debugging (Probe Failure)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvcmVhZGluZXNzUHJvYmUvaHR0cEdldC9wb3J0IiwidmFsdWUiOjMwMDB9LHsib3AiOiJyZXBsYWNlIiwicGF0aCI6Ii9zcGVjL3RlbXBsYXRlL3NwZWMvY29udGFpbmVycy8wL2xpdmVuZXNzUHJvYmUvaHR0cEdldC9wb3J0IiwidmFsdWUiOjMwMDB9XScgJiYgY2xlYXI=" | base64 -d | bash && clear
```

Wait ~30 seconds for the rollout to begin and probes to start failing, then hand over.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API has become unreliable — it's returning errors intermittently and some requests time out. Can you figure out what's going on?"

## Timer

15 minutes.
