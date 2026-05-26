#!/bin/bash
# Networking Lab 3 Rollback: Start partner EC2 instance
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-nlb-failure-instance.txt"

echo "=== Networking Lab 3: NLB Target Failure Rollback ==="
echo ""

if [ -f "$BACKUP_FILE" ]; then
  INSTANCE_ID=$(cat "$BACKUP_FILE")
else
  echo "No backup file found. Searching for stopped partner instance..."
  INSTANCE_ID=$(AWS_PAGER="" aws ec2 describe-instances --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=partner-service" "Name=instance-state-name,Values=stopped" \
    --query "Reservations[0].Instances[0].InstanceId" --output text)
fi

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "ERROR: No stopped partner instance found"
  exit 1
fi

echo "[1/2] Starting instance $INSTANCE_ID..."
AWS_PAGER="" aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" > /dev/null
echo "  Start initiated"

echo ""
echo "[2/2] Cleaning up..."
rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
echo "Instance will be running in ~60 seconds. NLB health checks pass in ~90 seconds after that."
