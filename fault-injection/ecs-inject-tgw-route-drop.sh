#!/bin/bash
# Networking Lab 1: TGW Route Blackhole
# Removes the transit gateway route for the partner VPC CIDR, breaking cross-VPC connectivity.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
PARTNER_CIDR="${PARTNER_CIDR:-10.1.0.0/16}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Networking Lab 1: TGW Route Blackhole Injection ==="
echo ""

echo "[1/3] Discovering Transit Gateway..."
TGW_ID=$(AWS_PAGER="" aws ec2 describe-transit-gateways --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=networking-demo-tgw" "Name=state,Values=available" \
  --query "TransitGateways[0].TransitGatewayId" --output text)

if [ "$TGW_ID" = "None" ] || [ -z "$TGW_ID" ]; then
  echo "ERROR: No Transit Gateway found with tag 'networking-demo-tgw'"
  exit 1
fi
echo "  TGW: $TGW_ID"

TGW_RT_ID=$(AWS_PAGER="" aws ec2 describe-transit-gateway-route-tables --region "$AWS_REGION" \
  --filters "Name=transit-gateway-id,Values=$TGW_ID" "Name=default-association-route-table,Values=true" \
  --query "TransitGatewayRouteTables[0].TransitGatewayRouteTableId" --output text)
echo "  Route Table: $TGW_RT_ID"

echo ""
echo "[2/3] Checking current route for $PARTNER_CIDR..."
CURRENT_ROUTE=$(AWS_PAGER="" aws ec2 search-transit-gateway-routes --region "$AWS_REGION" \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --filters "Name=route-search.exact-match,Values=$PARTNER_CIDR" \
  --query "Routes[0]" --output json 2>/dev/null || echo "null")

if [ "$CURRENT_ROUTE" = "null" ]; then
  echo "  WARNING: No exact route found for $PARTNER_CIDR (may be propagated)"
fi

echo ""
echo "[3/3] Creating blackhole route (overrides propagated route)..."
AWS_PAGER="" aws ec2 replace-transit-gateway-route --region "$AWS_REGION" \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --destination-cidr-block "$PARTNER_CIDR" \
  --blackhole 2>/dev/null || \
AWS_PAGER="" aws ec2 create-transit-gateway-route --region "$AWS_REGION" \
  --transit-gateway-route-table-id "$TGW_RT_ID" \
  --destination-cidr-block "$PARTNER_CIDR" \
  --blackhole

echo "  Route $PARTNER_CIDR → blackhole"

jq -n "{\"region\": \"$AWS_REGION\", \"tgw_id\": \"$TGW_ID\", \"tgw_rt_id\": \"$TGW_RT_ID\", \"cidr\": \"$PARTNER_CIDR\"}" > "$SCRIPT_DIR/ecs-tgw-route-drop.json"
echo "  Backup saved to: $SCRIPT_DIR/ecs-tgw-route-drop.json"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: TGW route for $PARTNER_CIDR set to blackhole"
echo ""
echo "Expected alarms (within 2 minutes):"
echo "  1. networking-demo-cross-vpc-connectivity-down"
echo "  2. networking-demo-nlb-unhealthy-targets"
echo "  3. networking-demo-dns-connectivity-down"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-tgw-route-drop.sh"
