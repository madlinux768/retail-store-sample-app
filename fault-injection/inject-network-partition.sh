#!/bin/bash
# Lab 5: Network Partition (UI -> Carts)
# Blocks traffic from UI namespace to Cart service using NetworkPolicy
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=== Lab 5: Network Partition Injection ==="
echo ""

echo "[1/2] Applying NetworkPolicy to block UI -> Carts traffic..."
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-ui-to-carts
  namespace: carts
  labels:
    fault-injection: "true"
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: carts
      app.kubernetes.io/owner: retail-store-sample
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchExpressions:
        - key: kubernetes.io/metadata.name
          operator: NotIn
          values:
          - ui
EOF

echo "[2/2] Verifying NetworkPolicy..."
kubectl get networkpolicy -n carts

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Blocked: UI namespace -> Cart service"
echo "Allowed: All other namespaces -> Cart service"
echo "Expected: Website appears up but cart functionality is broken"
echo ""
echo "Rollback: ./fault-injection/rollback-network-partition.sh"
