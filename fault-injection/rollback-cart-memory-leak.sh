#!/bin/bash
# Lab 2 Rollback: Restore cart service
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

NAMESPACE="carts"
DEPLOYMENT="carts"

echo "=== Lab 2: Cart Memory Leak Rollback ==="
echo ""

echo "[1/3] Restoring memory limits and removing sidecar..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "512Mi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "512Mi"}
]'
kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE

echo "[2/3] Waiting for rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo "[3/3] Cleaning up ConfigMap..."
kubectl delete configmap memory-leak-script -n $NAMESPACE --ignore-not-found=true

echo ""
echo "=== Rollback Complete ==="
kubectl get pods -n $NAMESPACE
