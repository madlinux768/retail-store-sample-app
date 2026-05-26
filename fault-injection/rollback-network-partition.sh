#!/bin/bash
# Lab 5 Rollback: Remove NetworkPolicy
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=== Lab 5: Network Partition Rollback ==="
echo ""

kubectl delete networkpolicy block-ui-to-carts -n carts --ignore-not-found=true

echo ""
echo "=== Rollback Complete ==="
echo "Traffic restored: UI -> Cart service"
