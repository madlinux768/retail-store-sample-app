#!/bin/bash
# ECS Lab 3: RDS Security Group Misconfiguration
# Removes ingress rules allowing ECS tasks to connect to RDS instances
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
ENV_NAME="${ENV_NAME:-retail-store-ecs}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ECS Lab 3: RDS Security Group Block Injection ==="
echo ""

echo "[1/4] Discovering ECS service security groups..."
CATALOG_SG=$(AWS_PAGER="" aws ecs describe-services --cluster "$CLUSTER_NAME" --services catalog \
  --region "$AWS_REGION" --query "services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]" --output text)
ORDERS_SG=$(AWS_PAGER="" aws ecs describe-services --cluster "$CLUSTER_NAME" --services orders \
  --region "$AWS_REGION" --query "services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]" --output text)

echo "  Catalog task SG: $CATALOG_SG"
echo "  Orders task SG: $ORDERS_SG"
echo ""

echo "[2/4] Discovering RDS clusters and their security groups..."
RDS_INFO=$(AWS_PAGER="" aws rds describe-db-clusters --region "$AWS_REGION" \
  --db-cluster-identifier "${ENV_NAME}-catalog" \
  --query "DBClusters[0].{Id:DBClusterIdentifier,SG:VpcSecurityGroups[0].VpcSecurityGroupId,Port:Port}" --output json)
CATALOG_RDS_SG=$(echo "$RDS_INFO" | jq -r '.SG')
CATALOG_RDS_PORT=$(echo "$RDS_INFO" | jq -r '.Port')

RDS_INFO=$(AWS_PAGER="" aws rds describe-db-clusters --region "$AWS_REGION" \
  --db-cluster-identifier "${ENV_NAME}-orders" \
  --query "DBClusters[0].{Id:DBClusterIdentifier,SG:VpcSecurityGroups[0].VpcSecurityGroupId,Port:Port}" --output json)
ORDERS_RDS_SG=$(echo "$RDS_INFO" | jq -r '.SG')
ORDERS_RDS_PORT=$(echo "$RDS_INFO" | jq -r '.Port')

echo "  Catalog RDS SG: $CATALOG_RDS_SG (port $CATALOG_RDS_PORT)"
echo "  Orders RDS SG: $ORDERS_RDS_SG (port $ORDERS_RDS_PORT)"
echo ""

echo "[3/4] Revoking security group rules..."
REVOKED_RULES="[]"

if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$CATALOG_RDS_SG" --protocol tcp --port "$CATALOG_RDS_PORT" \
  --source-group "$CATALOG_SG" --region "$AWS_REGION" 2>/dev/null; then
  echo "  Revoked: Catalog task SG → Catalog RDS (port $CATALOG_RDS_PORT)"
  REVOKED_RULES=$(echo "$REVOKED_RULES" | jq ". + [{\"rds_sg\": \"$CATALOG_RDS_SG\", \"task_sg\": \"$CATALOG_SG\", \"port\": $CATALOG_RDS_PORT, \"service\": \"catalog\"}]")
else
  echo "  Warning: Could not revoke Catalog RDS rule (may already be removed)"
fi

if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
  --group-id "$ORDERS_RDS_SG" --protocol tcp --port "$ORDERS_RDS_PORT" \
  --source-group "$ORDERS_SG" --region "$AWS_REGION" 2>/dev/null; then
  echo "  Revoked: Orders task SG → Orders RDS (port $ORDERS_RDS_PORT)"
  REVOKED_RULES=$(echo "$REVOKED_RULES" | jq ". + [{\"rds_sg\": \"$ORDERS_RDS_SG\", \"task_sg\": \"$ORDERS_SG\", \"port\": $ORDERS_RDS_PORT, \"service\": \"orders\"}]")
else
  echo "  Warning: Could not revoke Orders RDS rule (may already be removed)"
fi

echo "$REVOKED_RULES" | jq "{\"region\": \"$AWS_REGION\", \"cluster\": \"$CLUSTER_NAME\", \"revoked_rules\": .}" > "$SCRIPT_DIR/ecs-rds-sg-ids.json"
echo ""
echo "  Backup saved to: $SCRIPT_DIR/ecs-rds-sg-ids.json"

echo ""
echo "[4/4] Force-deploying services to trigger connection errors..."
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER_NAME" --service catalog \
  --force-new-deployment --region "$AWS_REGION" > /dev/null && echo "  Force-deployed: catalog"
AWS_PAGER="" aws ecs update-service --cluster "$CLUSTER_NAME" --service orders \
  --force-new-deployment --region "$AWS_REGION" > /dev/null && echo "  Force-deployed: orders"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: RDS security group rules revoked (catalog port $CATALOG_RDS_PORT, orders port $ORDERS_RDS_PORT)"
echo "Expected: catalog + orders tasks will fail DB health checks and restart"
echo "Alarms expected: orders-container-unhealthy, catalog-container-unhealthy, error-count-high"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-rds-sg-block.sh"
