#!/bin/bash
# ECS Lab 5 Rollback: Restore Carts Security Group
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-network-partition.json"

echo "=== ECS Lab 5: Network Partition Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  echo "Cannot rollback without knowing the original configuration."
  exit 1
fi

REGION=$(jq -r '.region' "$BACKUP_FILE")
CARTS_SG=$(jq -r '.carts_sg' "$BACKUP_FILE")
ORIGINAL_CIDR=$(jq -r '.original_cidr' "$BACKUP_FILE")
PORT=$(jq -r '.port' "$BACKUP_FILE")

echo "[1/3] Removing self-referencing rule..."
AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$CARTS_SG" --protocol tcp --port "$PORT" \
  --source-group "$CARTS_SG" --region "$REGION" 2>/dev/null || true
echo "  Removed self-referencing rule"

echo ""
echo "[2/3] Restoring original ingress rule..."
if AWS_PAGER="" aws ec2 authorize-security-group-ingress \
  --group-id "$CARTS_SG" --protocol tcp --port "$PORT" \
  --cidr "$ORIGINAL_CIDR" --region "$REGION" 2>/dev/null; then
  echo "  Restored: $ORIGINAL_CIDR:$PORT on carts SG ($CARTS_SG)"
else
  echo "  Warning: Rule may already exist"
fi

echo ""
echo "[3/3] Cleaning up..."
rm -f "$BACKUP_FILE"
echo "  Removed backup file"

echo ""
echo "=== Rollback Complete ==="
echo "Carts service is immediately accessible again. No service restart needed."
