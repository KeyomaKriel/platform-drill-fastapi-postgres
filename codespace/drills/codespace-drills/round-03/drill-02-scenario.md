# Drill 02 — Debugging (Django App)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGluY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6ImFkZCIsInBhdGgiOiIvc3BlYy90ZW1wbGF0ZS9zcGVjL2NvbnRhaW5lcnMvMC9jb21tYW5kIiwidmFsdWUiOlsiLi9pbmNpZGVudC1zZXJ2aWNlIl19XScgJiYgY2xlYXI=" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API went down after a recent change. Can you find out what happened?"

## Timer

15 minutes.
