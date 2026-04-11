#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="inventory-api"
IMAGE_NAME="inventory-api:local"
NAMESPACE="warehouse-sys"
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
kubectl rollout status deployment/inventory-db -n "$NAMESPACE" --timeout=90s

echo "=== Waiting for API ==="
kubectl rollout status deployment/inventory-api -n "$NAMESPACE" --timeout=120s

echo "=== Verifying ==="
kubectl get all -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "=== Health check ==="
for i in $(seq 1 10); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/readyz 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "Health: OK"
    curl -s http://localhost/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost/
    echo ""
    curl -s http://localhost/readyz | python3 -m json.tool 2>/dev/null || curl -s http://localhost/readyz
    echo ""
    curl -s http://localhost/api/v1/products | python3 -m json.tool 2>/dev/null || curl -s http://localhost/api/v1/products
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
