# Drill 05 — Debugging (Django App)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvcmVhZGluZXNzUHJvYmUvaHR0cEdldC9wYXRoIiwidmFsdWUiOiIvc3RhdHVzIn0seyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvbGl2ZW5lc3NQcm9iZS9odHRwR2V0L3BhdGgiLCJ2YWx1ZSI6Ii9zdGF0dXMifV0nICYmIGNsZWFy" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API is behaving erratically — sometimes it works, sometimes it doesn't. Users are frustrated. Can you look into it?"

## Timer

15 minutes.
