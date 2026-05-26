#!/bin/bash
# Networking Lab 4 Rollback: Restore Partner SG Ingress Rules
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-tgw-sg-block.json"

echo "=== Networking Lab 4: Partner SG Block Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

REGION=$(jq -r '.region' "$BACKUP_FILE")
PARTNER_SG=$(jq -r '.partner_sg' "$BACKUP_FILE")
APP_CIDR=$(jq -r '.app_cidr' "$BACKUP_FILE")

echo "[1/2] Restoring ingress rules on $PARTNER_SG..."

for rule in $(jq -c '.revoked_rules[]' "$BACKUP_FILE"); do
  PROTOCOL=$(echo "$rule" | jq -r '.protocol')
  PORT=$(echo "$rule" | jq -r '.port')
  CIDR=$(echo "$rule" | jq -r '.cidr')

  if [ "$PROTOCOL" = "icmp" ]; then
    AWS_PAGER="" aws ec2 authorize-security-group-ingress \
      --group-id "$PARTNER_SG" \
      --ip-permissions "IpProtocol=icmp,FromPort=-1,ToPort=-1,IpRanges=[{CidrIp=$CIDR}]" \
      --region "$REGION" 2>/dev/null && echo "  Restored: ICMP from $CIDR" || echo "  Warning: ICMP rule may already exist"
  else
    AWS_PAGER="" aws ec2 authorize-security-group-ingress \
      --group-id "$PARTNER_SG" --protocol "$PROTOCOL" --port "$PORT" \
      --cidr "$CIDR" --region "$REGION" 2>/dev/null && echo "  Restored: $PROTOCOL/$PORT from $CIDR" || echo "  Warning: Rule may already exist"
  fi
done

echo ""
echo "[2/2] Cleaning up..."
rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
echo "Partner service is immediately accessible again from app VPC."
