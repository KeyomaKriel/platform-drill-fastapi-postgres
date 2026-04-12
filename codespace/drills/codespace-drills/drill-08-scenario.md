# Drill 08 — Debugging (Go App)

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
echo "a3ViZWN0bCBwYXRjaCBkZXBsb3ltZW50IGludmVudG9yeS1hcGkgLW4gd2FyZWhvdXNlLXN5cyAtLXR5cGU9anNvbiAtcD0nW3sib3AiOiJhZGQiLCJwYXRoIjoiL3NwZWMvdGVtcGxhdGUvc3BlYy9jb250YWluZXJzLzAvY29tbWFuZCIsInZhbHVlIjpbIi4vaW52ZW50b3J5LXNlcnZpY2UiXX1dJw==" | base64 -d | bash && clear
```

## Start session log

```
cd /workspaces/platform-drill-fastapi-postgres/codespace/drill-app-go && script -q -a ./session.log
```

## Symptom prompt

> "The inventory service was recently updated and now it's not coming up. Can you take a look?"

## Timer

15 minutes.
