#!/bin/bash
# ECS Lab 4 Rollback: Stop DynamoDB Stress Task
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
ENV_NAME="${ENV_NAME:-retail-store-ecs}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-dynamodb-stress-task.txt"

echo "=== ECS Lab 4: DynamoDB Stress Rollback ==="
echo ""

if [ -f "$BACKUP_FILE" ]; then
  TASK_ARN=$(cat "$BACKUP_FILE")
  echo "[1/2] Stopping stress task: $TASK_ARN"
  AWS_PAGER="" aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$TASK_ARN" \
    --reason "Fault injection rollback" --region "$AWS_REGION" > /dev/null 2>&1 || true
else
  echo "[1/2] No saved task ARN found. Searching for running stress tasks..."
  TASK_ARNS=$(AWS_PAGER="" aws ecs list-tasks --cluster "$CLUSTER_NAME" \
    --family "${ENV_NAME}-dynamodb-stress" --desired-status RUNNING \
    --region "$AWS_REGION" --query "taskArns[]" --output text)
  if [ -n "$TASK_ARNS" ] && [ "$TASK_ARNS" != "None" ]; then
    for arn in $TASK_ARNS; do
      echo "  Stopping: $arn"
      AWS_PAGER="" aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$arn" \
        --reason "Fault injection rollback" --region "$AWS_REGION" > /dev/null
    done
  else
    echo "  No running stress tasks found."
  fi
fi

echo ""
echo "[2/2] Cleaning up..."
rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
echo "DynamoDB throttle alarms will clear within 5 minutes as load drops."
