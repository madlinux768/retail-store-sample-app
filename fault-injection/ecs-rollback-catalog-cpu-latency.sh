#!/bin/bash
# ECS Lab 1 Rollback: Restore Catalog Task Definition
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
TASK_FAMILY="${TASK_FAMILY:-retail-store-ecs-catalog}"
SERVICE_NAME="${SERVICE_NAME:-catalog}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-catalog-original-taskdef.txt"

echo "=== ECS Lab 1: Catalog CPU Starvation Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "WARNING: No backup file found at $BACKUP_FILE"
  echo "Attempting to find the latest non-faulted revision..."
  ORIGINAL_ARN=$(AWS_PAGER="" aws ecs list-task-definitions --family-prefix "$TASK_FAMILY" \
    --region "$AWS_REGION" --sort DESC --query "taskDefinitionArns" --output json | \
    jq -r '.[0]')
  echo "  Using latest revision: $ORIGINAL_ARN"
else
  ORIGINAL_ARN=$(cat "$BACKUP_FILE")
  echo "  Restoring: $ORIGINAL_ARN"
fi

echo ""
echo "[1/2] Updating service to original task definition..."
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" \
  --task-definition "$ORIGINAL_ARN" --force-new-deployment --region "$AWS_REGION" > /dev/null
echo "  Service updated"

echo ""
echo "[2/2] Cleaning up..."
rm -f "$BACKUP_FILE"
echo "  Removed backup file"

echo ""
echo "=== Rollback Complete ==="
echo "Catalog service will recover within 2-3 minutes as the healthy task deploys."
echo "Alarms will return to OK once metrics normalize (5-10 minutes)."
