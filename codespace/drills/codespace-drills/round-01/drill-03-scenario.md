# Drill 03 — Debugging

## Setup

App is already deployed and healthy in the Codespace.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGZsZWV0LXRyYWNrZXIgLW4gZmxlZXQtb3BzIC0tdHlwZT0nanNvbicgLXA9J1t7Im9wIjogInJlcGxhY2UiLCAicGF0aCI6ICIvc3BlYy90ZW1wbGF0ZS9zcGVjL2NvbnRhaW5lcnMvMC9yZWFkaW5lc3NQcm9iZS9odHRwR2V0L3BvcnQiLCAidmFsdWUiOiA4MDgwfV0n" | base64 -d | bash && clear
```

## Start session log

```
cd ~/drill-app && script -q -a ./session.log
```

## Symptom prompt

> "The fleet tracker was working earlier, but now requests to the API are timing out. The pods seem to be running though. Can you figure out what's going on?"

## Timer

15 minutes.
