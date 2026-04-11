# Drill 04 — Debugging

## Setup

App is already deployed and healthy in the Codespace.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBwYXRjaCBzZXJ2aWNlIHRyYWNrZXItc3ZjIC1uIGZsZWV0LW9wcyAtcCAneyJzcGVjIjp7InNlbGVjdG9yIjp7ImNvbXBvbmVudCI6IndlYiJ9fX0n" | base64 -d | bash && clear
```

## Start session log

```
cd ~/drill-app && script -q -a ./session.log
```

## Symptom prompt

> "Users are saying the fleet tracker is down. Can you check on it?"

## Timer

15 minutes.
