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
echo "a3ViZWN0bCBzY2FsZSBkZXBsb3ltZW50L2luY2lkZW50LWRiIC1uIGluY2lkZW50LW1nbXQgLS1yZXBsaWNhcz0wICYmIGNsZWFy" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API has started returning errors. Users say they can't load incidents anymore and the status page looks wrong. Can you take a look?"

## Timer

15 minutes.
