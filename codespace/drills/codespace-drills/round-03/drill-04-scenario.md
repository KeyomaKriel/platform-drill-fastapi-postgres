# Drill 04 — Debugging (Django App)

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
echo "a3ViZWN0bCBzZXQgaW1hZ2UgZGVwbG95bWVudC9pbmNpZGVudC1hcGkgaW5jaWRlbnQtYXBpPWluY2lkZW50LWFwaTp2MS41LjAgLW4gaW5jaWRlbnQtbWdtdCAmJiBjbGVhcgo=" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API seems to be having issues after a deployment. Can you check what's going on?"

## Timer

15 minutes.
