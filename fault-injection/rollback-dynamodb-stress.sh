#!/bin/bash
# Lab 4 Rollback: Remove DynamoDB stress pod
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

NAMESPACE="carts"

echo "=== Lab 4: DynamoDB Stress Rollback ==="
echo ""

kubectl delete pod dynamodb-stress-test -n $NAMESPACE --ignore-not-found=true
kubectl delete configmap dynamodb-stress-script -n $NAMESPACE --ignore-not-found=true

echo ""
echo "=== Rollback Complete (instant - read-only test) ==="
