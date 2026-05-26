#!/bin/bash
# Networking Lab 1 Rollback: Remove TGW Blackhole Route
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-tgw-route-drop.json"

echo "=== Networking Lab 1: TGW Route Blackhole Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

REGION=$(jq -r '.region' "$BACKUP_FILE")
TGW_RT_ID=$(jq -r '.tgw_rt_id' "$BACKUP_FILE")
CIDR=$(jq -r '.cidr' "$BACKUP_FILE")

echo "[1/2] Removing blackhole route for $CIDR..."
AWS_PAGER="" aws ec2 delete-transit-gateway-route --region "$REGION" \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --destination-cidr-block "$CIDR"
echo "  Deleted blackhole route"
echo "  (Propagated route from TGW attachment will re-establish automatically)"

echo ""
echo "[2/2] Cleaning up..."
rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
echo "Cross-VPC connectivity will restore within 1-2 minutes as propagated routes take effect."
