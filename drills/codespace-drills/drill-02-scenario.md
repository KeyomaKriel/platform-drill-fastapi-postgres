# Drill 02 — Debugging

## Setup

App is already deployed and healthy in the Codespace.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBzZXQgZW52IGRlcGxveW1lbnQvZmxlZXQtdHJhY2tlciAtbiBmbGVldC1vcHMgUEdIT1NUPWZsZWV0LWRiICYmIGt1YmVjdGwgcm9sbG91dCBzdGF0dXMgZGVwbG95bWVudC9mbGVldC10cmFja2VyIC1uIGZsZWV0LW9wcyAtLXRpbWVvdXQ9NjBz" | base64 -d | bash && clear
```

## Start session log

```
cd ~/drill-app && script -q -a ./session.log
```

## Symptom prompt

> "Hey, the fleet tracker API was working fine earlier but now something seems off. Can you take a look?"

## Timer

15 minutes.
