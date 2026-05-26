#!/bin/bash
# Networking Lab 4: Security Group Block on Partner Service
# Revokes the ingress rule that allows traffic from the app VPC CIDR,
# blocking all cross-VPC communication at the SG level.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
APP_VPC_CIDR="${APP_VPC_CIDR:-10.0.0.0/16}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Networking Lab 4: Partner SG Block Injection ==="
echo ""

echo "[1/2] Discovering partner service security group..."
PARTNER_SG=$(AWS_PAGER="" aws ec2 describe-security-groups --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=partner-service-sg" \
  --query "SecurityGroups[0].GroupId" --output text)

if [ "$PARTNER_SG" = "None" ] || [ -z "$PARTNER_SG" ]; then
  echo "ERROR: No security group found with tag 'partner-service-sg'"
  exit 1
fi
echo "  Partner SG: $PARTNER_SG"

echo ""
echo "[2/2] Revoking ingress from app VPC CIDR ($APP_VPC_CIDR)..."
REVOKED="[]"

if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$PARTNER_SG" --protocol tcp --port 80 \
  --cidr "$APP_VPC_CIDR" --region "$AWS_REGION" 2>/dev/null; then
  echo "  Revoked: TCP/80 from $APP_VPC_CIDR"
  REVOKED=$(echo "$REVOKED" | jq ". + [{\"protocol\": \"tcp\", \"port\": 80, \"cidr\": \"$APP_VPC_CIDR\"}]")
fi

if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$PARTNER_SG" --ip-permissions "IpProtocol=icmp,FromPort=-1,ToPort=-1,IpRanges=[{CidrIp=$APP_VPC_CIDR}]" \
  --region "$AWS_REGION" 2>/dev/null; then
  echo "  Revoked: ICMP from $APP_VPC_CIDR"
  REVOKED=$(echo "$REVOKED" | jq ". + [{\"protocol\": \"icmp\", \"port\": -1, \"cidr\": \"$APP_VPC_CIDR\"}]")
fi

jq -n "{\"region\": \"$AWS_REGION\", \"partner_sg\": \"$PARTNER_SG\", \"app_cidr\": \"$APP_VPC_CIDR\", \"revoked_rules\": $REVOKED}" > "$SCRIPT_DIR/ecs-tgw-sg-block.json"
echo "  Backup saved to: $SCRIPT_DIR/ecs-tgw-sg-block.json"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: Partner SG blocks all traffic from app VPC ($APP_VPC_CIDR)"
echo ""
echo "Expected alarms (within 2 minutes):"
echo "  1. networking-demo-cross-vpc-connectivity-down"
echo "  2. networking-demo-nlb-unhealthy-targets"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-tgw-sg-block.sh"
