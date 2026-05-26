#!/bin/bash
# Lab 1 Rollback: Restore catalog service
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

NAMESPACE="catalog"
DEPLOYMENT="catalog"

echo "=== Lab 1: Catalog Service Rollback ==="
echo ""

echo "[1/3] Cleaning up ConfigMap..."
kubectl delete configmap latency-injector-script -n $NAMESPACE --ignore-not-found=true

echo "[2/3] Removing sidecar and restoring CPU limits..."
SIDECAR_EXISTS=$(kubectl get deployment $DEPLOYMENT -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[?(@.name=="latency-injector")].name}' 2>/dev/null)

if [ -n "$SIDECAR_EXISTS" ]; then
  kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='json' -p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "256m"},
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "256m"},
    {"op": "remove", "path": "/spec/template/spec/containers/1"},
    {"op": "remove", "path": "/spec/template/spec/volumes/1"}
  ]' 2>/dev/null || {
    echo "  Patch failed, restarting deployment..."
    kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='json' -p='[
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "256m"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "256m"}
    ]'
    kubectl rollout restart deployment/$DEPLOYMENT -n $NAMESPACE
  }
else
  echo "  No sidecar found, restoring CPU limits only..."
  kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='json' -p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/cpu", "value": "256m"},
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/cpu", "value": "256m"}
  ]'
fi

echo "[3/3] Waiting for rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo ""
echo "=== Rollback Complete ==="
kubectl get pods -n $NAMESPACE
