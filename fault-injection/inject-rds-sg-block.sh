#!/bin/bash
# Lab 3: RDS Security Group Misconfiguration
# Removes ingress rules allowing EKS to connect to RDS instances
set -e

export AWS_PROFILE="${AWS_PROFILE:-benpte-second}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Lab 3: RDS Security Group Block Injection ==="
echo ""

echo "[1/4] Discovering EKS cluster security group..."
EKS_CLUSTER=$(AWS_PAGER="" aws eks list-clusters --region $AWS_REGION --query "clusters[0]" --output text)
EKS_SG=$(AWS_PAGER="" aws eks describe-cluster --region $AWS_REGION --name "$EKS_CLUSTER" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

echo "  EKS Cluster: $EKS_CLUSTER"
echo "  EKS Security Group: $EKS_SG"
echo ""

echo "[2/4] Discovering RDS instances..."
RDS_INFO=$(AWS_PAGER="" aws rds describe-db-instances --region $AWS_REGION \
  --query "DBInstances[*].[DBInstanceIdentifier,VpcSecurityGroups[0].VpcSecurityGroupId,Endpoint.Port]" \
  --output json)

echo "$RDS_INFO" | jq -r '.[] | "  - \(.[0]) (SG: \(.[1]), Port: \(.[2]))"'
echo ""

echo "[3/4] Revoking security group rules..."
REVOKED_RULES="[]"

for row in $(echo "$RDS_INFO" | jq -r '.[] | @base64'); do
  _jq() { echo ${row} | base64 --decode | jq -r ${1}; }
  DB_ID=$(_jq '.[0]')
  RDS_SG=$(_jq '.[1]')
  DB_PORT=$(_jq '.[2]')

  echo "  Processing: $DB_ID"

  if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
    --group-id $RDS_SG --protocol tcp --port 5432 \
    --source-group $EKS_SG --region $AWS_REGION 2>/dev/null; then
    echo "    Revoked port 5432 (PostgreSQL)"
    REVOKED_RULES=$(echo "$REVOKED_RULES" | jq ". + [{\"rds_sg\": \"$RDS_SG\", \"eks_sg\": \"$EKS_SG\", \"port\": 5432, \"db_id\": \"$DB_ID\"}]")
  fi

  if AWS_PAGER="" aws ec2 revoke-security-group-ingress \
    --group-id $RDS_SG --protocol tcp --port 3306 \
    --source-group $EKS_SG --region $AWS_REGION 2>/dev/null; then
    echo "    Revoked port 3306 (MySQL)"
    REVOKED_RULES=$(echo "$REVOKED_RULES" | jq ". + [{\"rds_sg\": \"$RDS_SG\", \"eks_sg\": \"$EKS_SG\", \"port\": 3306, \"db_id\": \"$DB_ID\"}]")
  fi
done

echo "{\"region\": \"$AWS_REGION\", \"eks_sg\": \"$EKS_SG\", \"revoked_rules\": $REVOKED_RULES}" > "$SCRIPT_DIR/rds-sg-ids.json"
echo ""
echo "  Backup saved to: $SCRIPT_DIR/rds-sg-ids.json"

echo ""
echo "[4/4] Restarting pods to trigger connection errors..."
kubectl rollout restart deployment -n catalog catalog 2>/dev/null && echo "  Restarted catalog"
kubectl rollout restart deployment -n orders orders 2>/dev/null && echo "  Restarted orders"
kubectl rollout restart deployment -n checkout checkout 2>/dev/null && echo "  Restarted checkout"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: RDS security group rules revoked (ports 3306, 5432)"
echo "Expected: catalog + orders pods will crash-loop on DB connection failure"
echo ""
echo "Rollback: ./fault-injection/rollback-rds-sg-block.sh"
