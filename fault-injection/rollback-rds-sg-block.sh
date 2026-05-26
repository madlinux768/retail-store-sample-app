#!/bin/bash
# Lab 3 Rollback: Restore RDS security group rules
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/rds-sg-ids.json"

echo "=== Lab 3: RDS Security Group Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: No backup file found at $BACKUP_FILE"
  echo "Cannot rollback without knowing which rules were revoked."
  exit 1
fi

REGION=$(jq -r '.region' "$BACKUP_FILE")
REVOKED_RULES=$(jq -r '.revoked_rules' "$BACKUP_FILE")

echo "[1/3] Restoring security group rules..."
for row in $(echo "$REVOKED_RULES" | jq -r '.[] | @base64'); do
  _jq() { echo ${row} | base64 --decode | jq -r ${1}; }
  RDS_SG=$(_jq '.rds_sg')
  EKS_SG=$(_jq '.eks_sg')
  PORT=$(_jq '.port')
  DB_ID=$(_jq '.db_id')

  echo "  Restoring: $DB_ID (Port: $PORT)"
  if AWS_PAGER="" aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG --protocol tcp --port $PORT \
    --source-group $EKS_SG --region $REGION 2>/dev/null; then
    echo "    Restored"
  else
    echo "    Already exists or failed"
  fi
done

echo ""
echo "[2/3] Restarting pods..."
kubectl rollout restart deployment -n catalog catalog 2>/dev/null && echo "  Restarted catalog"
kubectl rollout restart deployment -n orders orders 2>/dev/null && echo "  Restarted orders"
kubectl rollout restart deployment -n checkout checkout 2>/dev/null && echo "  Restarted checkout"

echo "[3/3] Waiting for rollouts..."
kubectl rollout status deployment/catalog -n catalog --timeout=120s
kubectl rollout status deployment/orders -n orders --timeout=120s
kubectl rollout status deployment/checkout -n checkout --timeout=120s

rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
