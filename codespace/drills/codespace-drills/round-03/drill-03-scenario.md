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
echo "a3ViZWN0bCBwYXRjaCBjb25maWdtYXAgaW5jaWRlbnQtYXBpLWNvbmZpZyAtbiBpbmNpZGVudC1tZ210IC1wICd7ImRhdGEiOnsiUE9TVEdSRVNfSE9TVCI6ImluY2lkZW50LWRhdGFiYXNlIn19JyAmJiBrdWJlY3RsIHJvbGxvdXQgcmVzdGFydCBkZXBsb3kvaW5jaWRlbnQtYXBpIC1uIGluY2lkZW50LW1nbXQgJiYgY2xlYXI=" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API isn't responding. We're not sure what changed. Can you investigate?"

## Timer

15 minutes.
