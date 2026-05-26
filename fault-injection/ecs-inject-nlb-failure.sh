#!/bin/bash
# Networking Lab 3: Load Balancer Target Failure
# Stops the partner EC2 instance, causing NLB health checks to fail.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Networking Lab 3: NLB Target Failure Injection ==="
echo ""

echo "[1/2] Discovering partner EC2 instance..."
INSTANCE_ID=$(AWS_PAGER="" aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=partner-service" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
  echo "ERROR: No running instance found with tag 'partner-service'"
  exit 1
fi
echo "  Instance: $INSTANCE_ID"

echo ""
echo "[2/2] Stopping instance..."
AWS_PAGER="" aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" > /dev/null
echo "  Stop initiated"

echo "$INSTANCE_ID" > "$SCRIPT_DIR/ecs-nlb-failure-instance.txt"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: Partner service EC2 instance stopped ($INSTANCE_ID)"
echo ""
echo "Expected alarms (within 2-3 minutes):"
echo "  1. networking-demo-nlb-unhealthy-targets"
echo "  2. networking-demo-cross-vpc-connectivity-down"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-nlb-failure.sh"
