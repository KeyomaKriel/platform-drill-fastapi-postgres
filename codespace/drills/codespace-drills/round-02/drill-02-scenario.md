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
echo "a3ViZWN0bCBwYXRjaCBzdmMgaW5jaWRlbnQtYXBpLXN2YyAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvc2VsZWN0b3IvY29tcG9uZW50IiwidmFsdWUiOiJiYWNrZW5kIn1dJyAmJiBjbGVhcg==" | base64 -d | bash && clear
```

Wait ~5 seconds, then hand over.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API was working fine earlier today but now users are getting errors when they try to access it. Can you investigate?"

## Timer

15 minutes.
