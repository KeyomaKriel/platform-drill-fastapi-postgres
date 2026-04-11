# Drill 05 — Debugging

## Setup

App is already deployed and healthy in the Codespace.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBzY2FsZSBkZXBsb3ltZW50IGZsZWV0LWRiIC1uIGZsZWV0LW9wcyAtLXJlcGxpY2FzPTA=" | base64 -d | bash && clear
```

## Start session log

```
cd ~/drill-app && script -q -a ./session.log
```

## Symptom prompt

> "Something's not right with the fleet tracker. Users are getting errors. Can you look into it?"

## Timer

15 minutes.
