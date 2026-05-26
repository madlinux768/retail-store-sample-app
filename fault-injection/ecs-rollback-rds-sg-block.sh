#!/bin/bash
# ECS Lab 3 Rollback: Restore RDS Security Group Rules
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-rds-sg-ids.json"

echo "=== ECS Lab 3: RDS Security Group Block Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  echo "Cannot rollback without knowing which rules were revoked."
  exit 1
fi

REGION=$(jq -r '.region' "$BACKUP_FILE")
CLUSTER=$(jq -r '.cluster' "$BACKUP_FILE")
RULES=$(jq -c '.revoked_rules[]' "$BACKUP_FILE")

echo "[1/3] Restoring security group rules..."
while IFS= read -r rule; do
  RDS_SG=$(echo "$rule" | jq -r '.rds_sg')
  TASK_SG=$(echo "$rule" | jq -r '.task_sg')
  PORT=$(echo "$rule" | jq -r '.port')
  SERVICE=$(echo "$rule" | jq -r '.service')

  if AWS_PAGER="" aws ec2 authorize-security-group-ingress \
    --group-id "$RDS_SG" --protocol tcp --port "$PORT" \
    --source-group "$TASK_SG" --region "$REGION" 2>/dev/null; then
    echo "  Restored: $SERVICE task SG ($TASK_SG) → RDS SG ($RDS_SG) port $PORT"
  else
    echo "  Warning: Rule for $SERVICE may already exist"
  fi
done <<< "$RULES"

echo ""
echo "[2/3] Force-deploying services to reconnect..."
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER" --service catalog \
  --force-new-deployment --region "$REGION" > /dev/null && echo "  Force-deployed: catalog"
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER" --service orders \
  --force-new-deployment --region "$REGION" > /dev/null && echo "  Force-deployed: orders"

echo ""
echo "[3/3] Cleaning up..."
rm -f "$BACKUP_FILE"
echo "  Removed backup file"

echo ""
echo "=== Rollback Complete ==="
echo "Services will reconnect to RDS within 2-3 minutes as new tasks start."
