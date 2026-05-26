#!/bin/bash
# Networking Lab 2: DNS Resolution Failure
# Deletes the A records from the Route53 private hosted zone,
# causing DNS lookups for *.partner.internal to return NXDOMAIN.
#
# Note: We delete records rather than disassociating the VPC because AWS
# does not allow disassociating the last (and only) VPC from a PHZ.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Networking Lab 2: DNS Resolution Failure Injection ==="
echo ""

echo "[1/3] Discovering Route53 private hosted zone..."
ZONE_ID=$(AWS_PAGER="" aws route53 list-hosted-zones-by-name \
  --dns-name "partner.internal" --max-items 1 \
  --query "HostedZones[?Name=='partner.internal.' && Config.PrivateZone==\`true\`].Id" --output text | sed 's|/hostedzone/||')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
  echo "ERROR: No private hosted zone found for partner.internal"
  exit 1
fi
echo "  Zone ID: $ZONE_ID"

echo ""
echo "[2/3] Saving current records for rollback..."
RECORDS=$(AWS_PAGER="" aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  --query "ResourceRecordSets[?Type=='A']" --output json)

echo "$RECORDS" > "$SCRIPT_DIR/ecs-dns-failure.json"
RECORD_COUNT=$(echo "$RECORDS" | jq 'length')
echo "  Saved $RECORD_COUNT A record(s) to ecs-dns-failure.json"

echo ""
echo "[3/3] Deleting A records..."

CHANGES=$(echo "$RECORDS" | jq '[.[] | {"Action": "DELETE", "ResourceRecordSet": .}]')
CHANGE_BATCH=$(jq -n --argjson changes "$CHANGES" '{"Changes": $changes}')

AWS_PAGER="" aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "$CHANGE_BATCH" \
  --query 'ChangeInfo.Id' --output text

echo "  Deleted $RECORD_COUNT A record(s) from partner.internal"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: All A records deleted from partner.internal PHZ"
echo ""
echo "Expected behavior:"
echo "  - DNS lookups for api.partner.internal return NXDOMAIN"
echo "  - Direct IP connectivity still works (10.1.x.x via TGW)"
echo ""
echo "Expected alarms (within 2 minutes):"
echo "  1. networking-demo-dns-connectivity-down"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-dns-failure.sh"
