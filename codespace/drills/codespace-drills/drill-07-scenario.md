# Drill 07 — Debugging (Go App)

## Setup

The inventory API (`drill-app-go`) is deployed and healthy in the Codespace in the `warehouse-sys` namespace.

Verify before injecting:

```
curl localhost/api/v1/products
curl localhost/readyz
```

Both should return 200.

## Inject the fault

Paste this single command in the Codespace terminal:

```
echo "a3ViZWN0bCBwYXRjaCBpbmdyZXNzIGludmVudG9yeS1hcGktaW5ncmVzcyAtbiB3YXJlaG91c2Utc3lzIC0tdHlwZT1qc29uIC1wPSdbeyJvcCI6InJlcGxhY2UiLCJwYXRoIjoiL3NwZWMvaW5ncmVzc0NsYXNzTmFtZSIsInZhbHVlIjoidHJhZWZpayJ9XScK" | base64 -d | bash && clear
```

## Start session log

```
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go && script -q -a ./session.log
```

## Symptom prompt

> "We deployed the inventory API to this cluster. The pods look healthy but we can't reach the application from outside. Can you take a look?"

## Timer

15 minutes.
