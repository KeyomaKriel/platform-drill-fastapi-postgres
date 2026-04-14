# Drill 01 — Debugging (Django App)

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
echo "a3ViZWN0bCBwYXRjaCBzdmMgaW5jaWRlbnQtYXBpLXN2YyAtbiBpbmNpZGVudC1tZ210IC1wICd7InNwZWMiOnsic2VsZWN0b3IiOnsiY29tcG9uZW50Ijoid2ViIn19fScgJiYgY2xlYXIK" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "Something's not right with the incident API. Users are saying it's down but the team can't see anything obviously wrong. Can you take a look?"

## Timer

15 minutes.
