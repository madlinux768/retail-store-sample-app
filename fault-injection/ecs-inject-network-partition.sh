#!/bin/bash
# ECS Lab 5: Network Partition (UI → Carts)
# Removes the ingress rule on the carts security group that allows traffic from
# the UI task security group, breaking UI→carts communication.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ECS Lab 5: Network Partition (UI → Carts) Injection ==="
echo ""

echo "[1/3] Discovering service security groups..."
UI_SG=$(AWS_PAGER="" aws ecs describe-services --cluster "$CLUSTER_NAME" --services ui \
  --region "$AWS_REGION" --query "services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]" --output text)
CARTS_SG=$(AWS_PAGER="" aws ecs describe-services --cluster "$CLUSTER_NAME" --services carts \
  --region "$AWS_REGION" --query "services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]" --output text)

echo "  UI task SG: $UI_SG"
echo "  Carts task SG: $CARTS_SG"

echo ""
echo "[2/3] Getting VPC CIDR for the current ingress rule..."
# The carts SG currently allows 0.0.0.0/0:8080 — we'll replace it with a rule
# that only allows traffic from non-UI sources (effectively blocking UI→carts)
CURRENT_RULES=$(AWS_PAGER="" aws ec2 describe-security-groups --group-ids "$CARTS_SG" \
  --region "$AWS_REGION" --query "SecurityGroups[0].IpPermissions" --output json)

echo "  Current ingress rules on carts SG:"
echo "$CURRENT_RULES" | jq -r '.[] | "    Port \(.FromPort) from \(.IpRanges[0].CidrIp // .UserIdGroupPairs[0].GroupId // "unknown")"'

echo ""
echo "[3/3] Revoking 0.0.0.0/0 ingress and adding restricted rule..."

# Revoke the broad 0.0.0.0/0 rule
if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$CARTS_SG" --protocol tcp --port 8080 \
  --cidr "0.0.0.0/0" --region "$AWS_REGION" 2>/dev/null; then
  echo "  Revoked: 0.0.0.0/0:8080 on carts SG"
else
  echo "  Warning: Could not revoke 0.0.0.0/0 rule (may not exist in this form)"
fi

# Add a rule that only allows traffic from the carts SG itself (internal health checks)
# This effectively blocks UI, checkout, and all other services from reaching carts
AWS_PAGER="" aws ec2 authorize-security-group-ingress \
  --group-id "$CARTS_SG" --protocol tcp --port 8080 \
  --source-group "$CARTS_SG" --region "$AWS_REGION" 2>/dev/null || true
echo "  Added: self-referencing rule (only carts→carts allowed on 8080)"

# Save state for rollback
jq -n "{\"region\": \"$AWS_REGION\", \"carts_sg\": \"$CARTS_SG\", \"ui_sg\": \"$UI_SG\", \"original_cidr\": \"0.0.0.0/0\", \"port\": 8080}" > "$SCRIPT_DIR/ecs-network-partition.json"
echo "  Backup saved to: $SCRIPT_DIR/ecs-network-partition.json"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: Carts SG no longer accepts traffic from UI (or any other service)"
echo ""
echo "Expected behavior:"
echo "  - Website loads but cart operations fail silently (add to cart, view cart)"
echo "  - Checkout flow fails when attempting to read cart contents"
echo "  - Alarms: retail-store-ecs-error-count-high, retail-store-ecs-alb-target-5xx-high"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-network-partition.sh"
