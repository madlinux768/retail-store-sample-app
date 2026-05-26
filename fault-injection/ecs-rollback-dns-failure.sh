#!/bin/bash
# Networking Lab 2 Rollback: Restore A records to partner.internal PHZ
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="$SCRIPT_DIR/ecs-dns-failure.json"

echo "=== Networking Lab 2: DNS Resolution Failure Rollback ==="
echo ""

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "[1/3] Finding hosted zone..."
ZONE_ID=$(AWS_PAGER="" aws route53 list-hosted-zones-by-name \
  --dns-name "partner.internal" --max-items 1 \
  --query "HostedZones[?Name=='partner.internal.' && Config.PrivateZone==\`true\`].Id" --output text | sed 's|/hostedzone/||')

echo "  Zone ID: $ZONE_ID"

echo ""
echo "[2/3] Restoring A records from backup..."
RECORDS=$(cat "$BACKUP_FILE")
RECORD_COUNT=$(echo "$RECORDS" | jq 'length')

CHANGES=$(echo "$RECORDS" | jq '[.[] | {"Action": "UPSERT", "ResourceRecordSet": .}]')
CHANGE_BATCH=$(jq -n --argjson changes "$CHANGES" '{"Changes": $changes}')

AWS_PAGER="" aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "$CHANGE_BATCH" \
  --query 'ChangeInfo.Id' --output text

echo "  Restored $RECORD_COUNT A record(s)"

echo ""
echo "[3/3] Cleaning up..."
rm -f "$BACKUP_FILE"

echo ""
echo "=== Rollback Complete ==="
echo "DNS resolution for *.partner.internal will restore within 60 seconds."
echo "(Note: Lambda containers may cache NXDOMAIN for 1-2 minutes longer)"
