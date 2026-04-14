# Drill 06 — Debugging (Django App)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50L2luY2lkZW50LWFwaSAtbiBpbmNpZGVudC1tZ210IC0tdHlwZT1qc29uIC1wICdbeyJvcCI6ImFkZCIsInBhdGgiOiIvc3BlYy90ZW1wbGF0ZS9zcGVjL2NvbnRhaW5lcnMvMC9jb21tYW5kIiwidmFsdWUiOlsiZ3VuaWNvcm4iLCJjb25maWcud3NnaV9icm9rZW46YXBwbGljYXRpb24iLCItLWJpbmQiLCIwLjAuMC4wOjgyMDAiLCItLXdvcmtlcnMiLCIyIl19XScgJiYgY2xlYXI=" | base64 -d | bash && clear
```

Wait 30 seconds after injecting before starting.

## Start session log

```
cd ~/drill-app-django && script -q -a ./session.log
```

## Symptom prompt

> "The incident API has stopped responding. We haven't deployed any code changes recently, but something seems off. Can you figure out what's going on?"

## Timer

15 minutes.
