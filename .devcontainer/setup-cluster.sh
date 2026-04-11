#!/bin/bash
set -euo pipefail

echo "=== Installing k3d ==="
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "=== Creating k3d cluster ==="
k3d cluster create drill-cluster \
  -p "80:80@loadbalancer" \
  -p "443:443@loadbalancer" \
  --wait

echo "=== Verifying cluster ==="
kubectl cluster-info
kubectl get nodes

echo "=== Installing nginx ingress controller ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml

echo "=== Waiting for ingress controller ==="
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "=== Cluster ready ==="
kubectl get pods -A
