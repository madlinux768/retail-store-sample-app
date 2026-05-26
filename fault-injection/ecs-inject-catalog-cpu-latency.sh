#!/bin/bash
# ECS Lab 1: Catalog CPU Starvation + Latency (Cascade Trigger)
# Registers a new task definition with a stress-ng sidecar that consumes CPU,
# starving the catalog service and causing a cascade of latency/5xx alarms.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
TASK_FAMILY="${TASK_FAMILY:-retail-store-ecs-catalog}"
SERVICE_NAME="${SERVICE_NAME:-catalog}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ECS Lab 1: Catalog CPU Starvation Injection ==="
echo ""

echo "[1/4] Fetching current task definition..."
CURRENT_TASK_DEF=$(AWS_PAGER="" aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" --region "$AWS_REGION" \
  --query "taskDefinition" --output json)

CURRENT_ARN=$(echo "$CURRENT_TASK_DEF" | jq -r '.taskDefinitionArn')
echo "  Current: $CURRENT_ARN"

echo "$CURRENT_ARN" > "$SCRIPT_DIR/ecs-catalog-original-taskdef.txt"

echo ""
echo "[2/4] Building faulted task definition..."

# Strip read-only fields that register-task-definition won't accept
MODIFIED=$(echo "$CURRENT_TASK_DEF" | jq 'del(.taskDefinitionArn, .revision, .status,
  .requiresAttributes, .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)')

# Add stress-ng sidecar container that consumes nearly all CPU
# The task has 1024 CPU units total. We give stress-ng 900 and leave 124 for everything else.
STRESS_CONTAINER='{
  "name": "cpu-stress-injector",
  "image": "public.ecr.aws/amazonlinux/amazonlinux:2023-minimal",
  "cpu": 900,
  "memory": 128,
  "essential": false,
  "command": ["sh", "-c", "yum install -y stress-ng > /dev/null 2>&1 && stress-ng --cpu 4 --cpu-load 100 --timeout 0"],
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/retail-store-ecs",
      "awslogs-region": "'"$AWS_REGION"'",
      "awslogs-stream-prefix": "fault-injection"
    }
  }
}'

# Set per-container CPU limits: catalog-service gets only 64 CPU units
MODIFIED=$(echo "$MODIFIED" | jq --argjson stress "$STRESS_CONTAINER" '
  .containerDefinitions = [
    (.containerDefinitions[] |
      if .name == "catalog-service" then .cpu = 64 | .memory = 1024
      elif .name == "cloudwatch-agent" then .cpu = 30 | .memory = 256
      elif .name == "init" then .
      else . end
    ),
    $stress
  ]')

echo "  CPU allocation: catalog-service=64, cloudwatch-agent=30, stress-injector=900"

echo ""
echo "[3/4] Registering faulted task definition..."
NEW_ARN=$(AWS_PAGER="" aws ecs register-task-definition \
  --cli-input-json "$MODIFIED" --region "$AWS_REGION" \
  --query "taskDefinition.taskDefinitionArn" --output text)
echo "  Registered: $NEW_ARN"

echo ""
echo "[4/4] Deploying faulted task definition..."
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" \
  --task-definition "$NEW_ARN" --force-new-deployment --region "$AWS_REGION" > /dev/null
echo "  Service updated — new task deploying"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: CPU starvation on catalog service (64/1024 CPU units, stress-ng consuming 900)"
echo ""
echo "Expected cascade (within 2-5 minutes):"
echo "  1. retail-store-ecs-catalog-cpu-high (CPU > 80%)"
echo "  2. retail-store-ecs-alb-latency-p95-high (response time > 2s)"
echo "  3. retail-store-ecs-alb-target-5xx-high (timeouts → 5xx)"
echo "  4. retail-store-ecs-alb-5xx-anomaly (anomaly detection)"
echo ""
echo "Note: Deployment circuit breaker will auto-rollback in ~10 min if health checks fail."
echo "Original task def saved to: $SCRIPT_DIR/ecs-catalog-original-taskdef.txt"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-catalog-cpu-latency.sh"
