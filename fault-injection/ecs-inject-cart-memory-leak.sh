#!/bin/bash
# ECS Lab 2: Cart Memory Leak (OOMKill)
# Registers a new task definition with reduced memory limits and a memory-consuming
# sidecar that triggers OOMKill, causing container-unhealthy and running-tasks-low alarms.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
TASK_FAMILY="${TASK_FAMILY:-retail-store-ecs-carts}"
SERVICE_NAME="${SERVICE_NAME:-carts}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ECS Lab 2: Cart Memory Leak Injection ==="
echo ""

echo "[1/4] Fetching current task definition..."
CURRENT_TASK_DEF=$(AWS_PAGER="" aws ecs describe-task-definition \
  --task-definition "$TASK_FAMILY" --region "$AWS_REGION" \
  --query "taskDefinition" --output json)

CURRENT_ARN=$(echo "$CURRENT_TASK_DEF" | jq -r '.taskDefinitionArn')
echo "  Current: $CURRENT_ARN"

echo "$CURRENT_ARN" > "$SCRIPT_DIR/ecs-carts-original-taskdef.txt"

echo ""
echo "[2/4] Building faulted task definition..."

MODIFIED=$(echo "$CURRENT_TASK_DEF" | jq 'del(.taskDefinitionArn, .revision, .status,
  .requiresAttributes, .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)')

# Add a memory-consuming sidecar that will push the task over its memory limit.
# Task total is 2048 MiB. We allocate tight limits so the leak sidecar causes OOM.
LEAK_CONTAINER='{
  "name": "memory-leak-injector",
  "image": "public.ecr.aws/amazonlinux/amazonlinux:2023-minimal",
  "cpu": 64,
  "memoryReservation": 256,
  "essential": true,
  "command": ["sh", "-c", "i=0; while true; do dd if=/dev/zero of=/dev/shm/leak_$i bs=1M count=10 2>/dev/null; i=$((i+1)); sleep 3; done"],
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/retail-store-ecs",
      "awslogs-region": "'"$AWS_REGION"'",
      "awslogs-stream-prefix": "fault-injection"
    }
  },
  "linuxParameters": {
    "sharedMemorySize": 512
  }
}'

# Mark the leak container as essential so its OOMKill brings down the whole task
MODIFIED=$(echo "$MODIFIED" | jq --argjson leak "$LEAK_CONTAINER" '
  .containerDefinitions = [
    (.containerDefinitions[] |
      if .name == "carts-service" then .memoryReservation = 768
      elif .name == "cloudwatch-agent" then .memoryReservation = 256
      else . end
    ),
    $leak
  ]')

echo "  Memory allocation: carts-service=768 soft, leak-injector=256 soft (will grow to OOM)"
echo "  Leak container writes 10MB to /dev/shm every 3 seconds"

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
echo "Injected: Memory leak sidecar on carts service (10MB/3s to shared memory)"
echo ""
echo "Expected alarms (within 3-5 minutes):"
echo "  1. retail-store-ecs-carts-memory-high (memory > 85%)"
echo "  2. retail-store-ecs-carts-container-unhealthy (OOMKill)"
echo "  3. retail-store-ecs-carts-running-tasks-low (task dies, count < 1)"
echo ""
echo "Note: Deployment circuit breaker will auto-rollback in ~10 min."
echo "Original task def saved to: $SCRIPT_DIR/ecs-carts-original-taskdef.txt"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-cart-memory-leak.sh"
