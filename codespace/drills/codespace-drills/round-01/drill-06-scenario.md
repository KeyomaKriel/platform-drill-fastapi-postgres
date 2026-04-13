# Drill 06 — Debugging

## Setup

App is already deployed and healthy in the Codespace.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBzZXQgaW1hZ2UgZGVwbG95bWVudC9mbGVldC10cmFja2VyIHRyYWNrZXI9ZmxlZXQtdHJhY2tlcjp2Mi4xLjAgLW4gZmxlZXQtb3BzICYmIGt1YmVjdGwgcm9sbG91dCBzdGF0dXMgZGVwbG95bWVudC9mbGVldC10cmFja2VyIC1uIGZsZWV0LW9wcyAtLXRpbWVvdXQ9MzBzOyB0cnVl" | base64 -d | bash && clear
```

## Start session log

```
cd ~/drill-app && script -q -a ./session.log
```

## Symptom prompt

> "We're getting complaints about the fleet tracker again. Can you take a look?"

## Timer

15 minutes.
