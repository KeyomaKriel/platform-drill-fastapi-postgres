#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="fleet-tracker"
IMAGE_NAME="fleet-tracker:local"
NAMESPACE="fleet-ops"
CLUSTER_NAME="${K3D_CLUSTER:-drill-cluster}"

echo "=== Building $APP_NAME ==="
cd "$APP_DIR"
docker build -t "$IMAGE_NAME" .

echo "=== Loading image into k3d ==="
k3d image import "$IMAGE_NAME" -c "$CLUSTER_NAME"

echo "=== Creating namespace and applying manifests ==="
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/

echo "=== Waiting for database ==="
kubectl rollout status deployment/fleet-db -n "$NAMESPACE" --timeout=90s

echo "=== Waiting for API ==="
kubectl rollout status deployment/fleet-tracker -n "$NAMESPACE" --timeout=120s

echo "=== Verifying ==="
kubectl get all -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "=== Health check ==="
for i in $(seq 1 10); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/v1/status 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "Health: OK"
    curl -s http://localhost/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost/
    echo ""
    curl -s http://localhost/api/v1/status | python3 -m json.tool 2>/dev/null || curl -s http://localhost/api/v1/status
    echo ""
    curl -s http://localhost/api/v1/vehicles | python3 -m json.tool 2>/dev/null || curl -s http://localhost/api/v1/vehicles
    echo ""
    echo "=== $APP_NAME deployed and healthy ==="
    exit 0
  fi
  echo "Waiting for ingress... ($i/10)"
  sleep 5
done

echo "WARNING: Health check did not pass. Check pods and ingress manually."
kubectl get pods -n "$NAMESPACE"
kubectl logs -n "$NAMESPACE" -l component=api --tail=20
exit 1
