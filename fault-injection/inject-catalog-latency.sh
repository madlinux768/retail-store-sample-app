#!/bin/bash
# Lab 1: Catalog Service Performance Degradation
# Injects latency (300-500ms), reduces CPU limit, and generates CPU stress
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

NAMESPACE="catalog"
DEPLOYMENT="catalog"

echo "=== Lab 1: Catalog Service Fault Injection ==="
echo ""

echo "[1/3] Creating latency + CPU stress sidecar configuration..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: latency-injector-script
  namespace: catalog
data:
  inject-latency.sh: |
    #!/bin/sh
    apk add --no-cache iproute2 stress-ng >/dev/null 2>&1 || true
    tc qdisc add dev eth0 root netem delay 400ms 100ms distribution normal 2>/dev/null || \
    tc qdisc change dev eth0 root netem delay 400ms 100ms distribution normal
    echo "Latency injection active: 300-500ms on outbound traffic"
    echo "Starting CPU stress workers..."
    stress-ng --cpu 8 --cpu-load 100 --cpu-method all --aggressive --timeout 0 &
    while true; do
      echo "$(date): Latency + CPU stress running"
      sleep 30
    done
EOF

echo "[2/3] Patching deployment with fault injection..."
kubectl patch deployment $DEPLOYMENT -n $NAMESPACE --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/resources/limits/cpu",
    "value": "128m"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/cpu",
    "value": "128m"
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/-",
    "value": {
      "name": "latency-injector",
      "image": "alpine:3.18",
      "command": ["/bin/sh", "-c"],
      "args": ["cp /scripts/inject-latency.sh /tmp/inject.sh && chmod +x /tmp/inject.sh && /tmp/inject.sh"],
      "securityContext": {
        "capabilities": {
          "add": ["NET_ADMIN"]
        }
      },
      "resources": {
        "limits": {
          "cpu": "2000m",
          "memory": "512Mi"
        },
        "requests": {
          "cpu": "500m",
          "memory": "256Mi"
        }
      },
      "volumeMounts": [
        {
          "name": "latency-script",
          "mountPath": "/scripts"
        }
      ]
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {
      "name": "latency-script",
      "configMap": {
        "name": "latency-injector-script",
        "defaultMode": 493
      }
    }
  }
]'

echo "[3/3] Waiting for deployment rollout..."
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE --timeout=120s

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected:"
echo "  - Latency: 300-500ms on outbound HTTP"
echo "  - CPU limit: Main container reduced to 128m (throttling)"
echo "  - CPU stress: 8 workers at 100% in sidecar"
echo ""
echo "Rollback: ./fault-injection/rollback-catalog-latency.sh"
