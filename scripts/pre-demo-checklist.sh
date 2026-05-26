#!/bin/bash
# Pre-Demo Checklist — DevOps Agent 3-Space Demo
# Validates the entire demo environment is healthy before a live demo.
# Exits non-zero if any critical check fails.

set -o pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
APP_PROFILE="173471018689-app"
NETWORK_PROFILE="378147474529-network"
SECURITY_PROFILE="871440770885-security"
REGION="us-west-2"
APP_ACCOUNT="173471018689"

ECS_CLUSTER="retail-store-ecs-cluster"
ECS_SERVICES=("ui" "catalog" "carts" "orders" "checkout")

PARTNER_INSTANCE_ID="i-0ae35fba922471a0e"
CONNECTIVITY_LAMBDA="networking-demo-connectivity-check"

FAULT_INJECTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../fault-injection" && pwd)"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TOTAL=0
PASSED=0
FAILED=0
WARNED=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() {
  echo -e "${GREEN}[PASS]${RESET} $1"
  (( TOTAL++ )) || true
  (( PASSED++ )) || true
}

fail() {
  echo -e "${RED}[FAIL]${RESET} $1"
  (( TOTAL++ )) || true
  (( FAILED++ )) || true
}

warn() {
  echo -e "${YELLOW}[WARN]${RESET} $1"
  (( TOTAL++ )) || true
  (( WARNED++ )) || true
}

aws_app()      { AWS_PAGER="" aws --profile "$APP_PROFILE"      --region "$REGION" "$@"; }
aws_network()  { AWS_PAGER="" aws --profile "$NETWORK_PROFILE"  --region "$REGION" "$@"; }
aws_security() { AWS_PAGER="" aws --profile "$SECURITY_PROFILE" --region "$REGION" "$@"; }

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
echo "=== DevOps Agent 3-Space Demo — Pre-Demo Checklist ==="
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo ""

# ===========================================================================
# Space 1: DevOps Team
# ===========================================================================
echo "--- Space 1: DevOps Team ---"

# Check 1: All 5 ECS services running (desired=1, running=1)
RUNNING_COUNT=0
FAILED_SERVICES=()
for SVC in "${ECS_SERVICES[@]}"; do
  RESULT=$(aws_app ecs describe-services \
    --cluster "$ECS_CLUSTER" \
    --services "$SVC" \
    --query "services[0].{desired:desiredCount,running:runningCount}" \
    --output json 2>/dev/null)
  DESIRED=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('desired','?'))" 2>/dev/null)
  RUNNING=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('running','?'))" 2>/dev/null)
  if [[ "$RUNNING" == "$DESIRED" && "$DESIRED" == "1" ]]; then
    (( RUNNING_COUNT++ )) || true
  else
    FAILED_SERVICES+=("$SVC(${RUNNING}/${DESIRED})")
  fi
done

TOTAL_SVCS=${#ECS_SERVICES[@]}
if [[ $RUNNING_COUNT -eq $TOTAL_SVCS ]]; then
  pass "ECS services: ${RUNNING_COUNT}/${TOTAL_SVCS} running"
else
  FAILED_LIST=$(IFS=', '; echo "${FAILED_SERVICES[*]}")
  fail "ECS services: ${RUNNING_COUNT}/${TOTAL_SVCS} running — degraded: ${FAILED_LIST}"
fi

# Check 2: retail-store-ecs alarms in OK state
ALARM_DATA=$(aws_app cloudwatch describe-alarms \
  --alarm-name-prefix "retail-store-ecs" \
  --query "MetricAlarms[].{name:AlarmName,state:StateValue}" \
  --output json 2>/dev/null)
ALARM_COUNT=$(echo "$ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(len(a))" 2>/dev/null)
ALARMING=$(echo "$ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(sum(1 for x in a if x['state']=='ALARM'))" 2>/dev/null)
OK_COUNT=$(echo "$ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(sum(1 for x in a if x['state']=='OK'))" 2>/dev/null)
if [[ "$ALARMING" == "0" ]]; then
  pass "Alarms: ${OK_COUNT} OK, 0 in ALARM"
else
  ALARM_NAMES=$(echo "$ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(', '.join(x['name'] for x in a if x['state']=='ALARM'))" 2>/dev/null)
  warn "Alarms: ${OK_COUNT} OK, ${ALARMING} in ALARM — ${ALARM_NAMES}"
fi

# Check 3: X-Ray service graph has entries in last 5 minutes
START_TIME=$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(minutes=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null)
END_TIME=$(python3 -c "import datetime; print(datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'))" 2>/dev/null)
XRAY_RESULT=$(aws_app xray get-service-graph \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query "length(Services)" \
  --output text 2>/dev/null)
if [[ -n "$XRAY_RESULT" && "$XRAY_RESULT" -gt 0 ]] 2>/dev/null; then
  pass "X-Ray: traces present in last 5 min (${XRAY_RESULT} services)"
else
  fail "X-Ray: no traces in last 5 min (got: '${XRAY_RESULT}')"
fi

echo ""

# ===========================================================================
# Space 2: Security Team
# ===========================================================================
echo "--- Space 2: Security Team ---"

# Check 4: Security Hub active FSBP findings for account 173471018689
SECURITYHUB_COUNT=$(aws_security securityhub get-findings \
  --filters "{
    \"AwsAccountId\": [{\"Value\": \"${APP_ACCOUNT}\", \"Comparison\": \"EQUALS\"}],
    \"GeneratorId\": [{\"Value\": \"aws-foundational-security-best-practices\", \"Comparison\": \"PREFIX\"}],
    \"RecordState\": [{\"Value\": \"ACTIVE\", \"Comparison\": \"EQUALS\"}],
    \"WorkflowStatus\": [{\"Value\": \"NEW\", \"Comparison\": \"EQUALS\"}, {\"Value\": \"NOTIFIED\", \"Comparison\": \"EQUALS\"}]
  }" \
  --query "length(Findings)" \
  --output text 2>/dev/null)

if [[ -n "$SECURITYHUB_COUNT" && "$SECURITYHUB_COUNT" -gt 0 ]] 2>/dev/null; then
  pass "Security Hub: ${SECURITYHUB_COUNT} active FSBP findings"
elif [[ "$SECURITYHUB_COUNT" == "0" ]]; then
  fail "Security Hub: 0 active FSBP findings (expected > 0 for demo)"
else
  fail "Security Hub: unable to retrieve findings (got: '${SECURITYHUB_COUNT}')"
fi

# Check 5: GuardDuty detector is enabled
GD_DETECTORS=$(aws_security guardduty list-detectors \
  --query "DetectorIds" \
  --output json 2>/dev/null)
GD_DETECTOR_ID=$(echo "$GD_DETECTORS" | python3 -c "import sys,json; ids=json.load(sys.stdin); print(ids[0] if ids else '')" 2>/dev/null)

if [[ -n "$GD_DETECTOR_ID" ]]; then
  GD_STATUS=$(aws_security guardduty get-detector \
    --detector-id "$GD_DETECTOR_ID" \
    --query "Status" \
    --output text 2>/dev/null)
  GD_FINDINGS=$(aws_security guardduty list-findings \
    --detector-id "$GD_DETECTOR_ID" \
    --query "length(FindingIds)" \
    --output text 2>/dev/null)
  if [[ "$GD_STATUS" == "ENABLED" ]]; then
    pass "GuardDuty: detector enabled, ${GD_FINDINGS:-0} findings"
  else
    fail "GuardDuty: detector not enabled (status: ${GD_STATUS})"
  fi
else
  fail "GuardDuty: no detector found in security account"
fi

# Check 6: Inspector findings exist for account 173471018689
INSPECTOR_COUNT=$(aws_security inspector2 list-findings \
  --filter-criteria "{
    \"awsAccountId\": [{\"comparison\": \"EQUALS\", \"value\": \"${APP_ACCOUNT}\"}]
  }" \
  --query "length(findings)" \
  --output text 2>/dev/null)

if [[ -n "$INSPECTOR_COUNT" && "$INSPECTOR_COUNT" -gt 0 ]] 2>/dev/null; then
  pass "Inspector: ${INSPECTOR_COUNT} findings present for account ${APP_ACCOUNT}"
elif [[ "$INSPECTOR_COUNT" == "0" ]]; then
  fail "Inspector: 0 findings for account ${APP_ACCOUNT} (expected > 0 for demo)"
else
  fail "Inspector: unable to retrieve findings (got: '${INSPECTOR_COUNT}')"
fi

echo ""

# ===========================================================================
# Space 3: Networking Team
# ===========================================================================
echo "--- Space 3: Networking Team ---"

# Check 7: Partner EC2 is running
PARTNER_STATE=$(aws_network ec2 describe-instances \
  --instance-ids "$PARTNER_INSTANCE_ID" \
  --query "Reservations[0].Instances[0].{state:State.Name,ip:PrivateIpAddress}" \
  --output json 2>/dev/null)
if [[ -z "$PARTNER_STATE" || "$PARTNER_STATE" == "null" ]]; then
  # Fall back to tag-based lookup
  PARTNER_STATE=$(aws_network ec2 describe-instances \
    --filters "Name=tag:Name,Values=partner-service" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query "Reservations[0].Instances[0].{state:State.Name,ip:PrivateIpAddress}" \
    --output json 2>/dev/null)
fi
PARTNER_INST_STATE=$(echo "$PARTNER_STATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('state','unknown') if d else 'unknown')" 2>/dev/null)
PARTNER_IP=$(echo "$PARTNER_STATE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip','') if d else '')" 2>/dev/null)

if [[ "$PARTNER_INST_STATE" == "running" ]]; then
  pass "Partner EC2: running (${PARTNER_IP})"
else
  fail "Partner EC2: not running (state: ${PARTNER_INST_STATE:-unknown})"
fi

# Check 8: Lambda connectivity check returns ip_connectivity=1, dns_connectivity=1
LAMBDA_PAYLOAD=$(aws_app lambda invoke \
  --function-name "$CONNECTIVITY_LAMBDA" \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda-connectivity-response.json \
  --query "StatusCode" \
  --output text 2>/dev/null)
LAMBDA_STATUS=$?

if [[ $LAMBDA_STATUS -eq 0 && -f /tmp/lambda-connectivity-response.json ]]; then
  LAMBDA_RESULT=$(cat /tmp/lambda-connectivity-response.json 2>/dev/null)
  IP_CONN=$(echo "$LAMBDA_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip_connectivity','?'))" 2>/dev/null)
  DNS_CONN=$(echo "$LAMBDA_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('dns_connectivity','?'))" 2>/dev/null)
  rm -f /tmp/lambda-connectivity-response.json
  if [[ "$IP_CONN" == "1" && "$DNS_CONN" == "1" ]]; then
    pass "Connectivity: ip=${IP_CONN}, dns=${DNS_CONN}"
  else
    fail "Connectivity: ip=${IP_CONN}, dns=${DNS_CONN} (expected both=1)"
  fi
else
  rm -f /tmp/lambda-connectivity-response.json
  fail "Connectivity: Lambda invocation failed (status: ${LAMBDA_PAYLOAD:-error})"
fi

# Check 9: All 4 networking-demo alarms in OK state
NET_ALARM_DATA=$(aws_app cloudwatch describe-alarms \
  --alarm-name-prefix "networking-demo" \
  --query "MetricAlarms[].{name:AlarmName,state:StateValue}" \
  --output json 2>/dev/null)
NET_ALARM_TOTAL=$(echo "$NET_ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(len(a))" 2>/dev/null)
NET_ALARMING=$(echo "$NET_ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(sum(1 for x in a if x['state']=='ALARM'))" 2>/dev/null)
NET_OK=$(echo "$NET_ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(sum(1 for x in a if x['state']=='OK'))" 2>/dev/null)
if [[ "$NET_ALARMING" == "0" ]]; then
  pass "Alarms: ${NET_OK} OK, 0 in ALARM (${NET_ALARM_TOTAL} total networking-demo alarms)"
else
  NET_ALARM_NAMES=$(echo "$NET_ALARM_DATA" | python3 -c "import sys,json; a=json.load(sys.stdin); print(', '.join(x['name'] for x in a if x['state']=='ALARM'))" 2>/dev/null)
  fail "Alarms: ${NET_OK} OK, ${NET_ALARMING} in ALARM — ${NET_ALARM_NAMES}"
fi

# Check 10: NLB target is healthy
TG_ARN=$(aws_app elbv2 describe-target-groups \
  --names "partner-service-tg" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null)

if [[ -n "$TG_ARN" && "$TG_ARN" != "None" ]]; then
  TARGET_HEALTH=$(aws_app elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --query "TargetHealthDescriptions[].TargetHealth.State" \
    --output json 2>/dev/null)
  HEALTHY=$(echo "$TARGET_HEALTH" | python3 -c "import sys,json; s=json.load(sys.stdin); print(sum(1 for x in s if x=='healthy'))" 2>/dev/null)
  UNHEALTHY=$(echo "$TARGET_HEALTH" | python3 -c "import sys,json; s=json.load(sys.stdin); print(sum(1 for x in s if x!='healthy'))" 2>/dev/null)
  if [[ "$HEALTHY" -gt 0 && "$UNHEALTHY" == "0" ]] 2>/dev/null; then
    pass "NLB target: healthy (${HEALTHY} healthy)"
  else
    fail "NLB target: unhealthy (healthy=${HEALTHY}, unhealthy=${UNHEALTHY})"
  fi
else
  fail "NLB target: target group 'partner-service-tg' not found"
fi

# Check 11: TGW attachment is available
TGW_ATTACHMENT=$(aws_app ec2 describe-transit-gateway-attachments \
  --filters "Name=tag:Name,Values=app-vpc-attachment" \
  --query "TransitGatewayAttachments[0].State" \
  --output text 2>/dev/null)

if [[ "$TGW_ATTACHMENT" == "available" ]]; then
  pass "TGW attachment: available"
elif [[ -z "$TGW_ATTACHMENT" || "$TGW_ATTACHMENT" == "None" ]]; then
  # Try the partner attachment from networking account
  TGW_ATTACHMENT=$(aws_network ec2 describe-transit-gateway-attachments \
    --filters "Name=tag:Name,Values=partner-vpc-attachment" \
    --query "TransitGatewayAttachments[0].State" \
    --output text 2>/dev/null)
  if [[ "$TGW_ATTACHMENT" == "available" ]]; then
    pass "TGW attachment: available"
  else
    fail "TGW attachment: not available (state: ${TGW_ATTACHMENT:-not found})"
  fi
else
  fail "TGW attachment: not available (state: ${TGW_ATTACHMENT})"
fi

# Check 12: VPC flow logs are ACTIVE (networking account — partner VPC)
VPC_FLOW_LOG_STATUS=$(aws_network ec2 describe-flow-logs \
  --filter "Name=tag:Name,Values=networking-demo-partner-vpc-flow-log" \
  --query "FlowLogs[0].FlowLogStatus" \
  --output text 2>/dev/null)

if [[ "$VPC_FLOW_LOG_STATUS" == "ACTIVE" ]]; then
  pass "VPC flow logs: ACTIVE"
else
  fail "VPC flow logs: not ACTIVE (status: ${VPC_FLOW_LOG_STATUS:-not found})"
fi

# Check 13: TGW flow logs are ACTIVE (networking account)
TGW_FLOW_LOG_STATUS=$(aws_network ec2 describe-flow-logs \
  --filter "Name=tag:Name,Values=networking-demo-tgw-flow-log" \
  --query "FlowLogs[0].FlowLogStatus" \
  --output text 2>/dev/null)

if [[ "$TGW_FLOW_LOG_STATUS" == "ACTIVE" ]]; then
  pass "TGW flow logs: ACTIVE"
else
  fail "TGW flow logs: not ACTIVE (status: ${TGW_FLOW_LOG_STATUS:-not found})"
fi

echo ""

# ===========================================================================
# Cross-Cutting
# ===========================================================================
echo "--- Cross-Cutting ---"

# Check 14: No fault injection state files present
STALE_FILES=()
if [[ -d "$FAULT_INJECTION_DIR" ]]; then
  while IFS= read -r -d '' f; do
    STALE_FILES+=("$(basename "$f")")
  done < <(find "$FAULT_INJECTION_DIR" \( -name "ecs-*.json" -o -name "ecs-*-task.txt" -o -name "ecs-*-original-taskdef.txt" \) -print0 2>/dev/null)
fi

if [[ ${#STALE_FILES[@]} -eq 0 ]]; then
  pass "No stale fault injection state files"
else
  FILE_LIST=$(IFS=', '; echo "${STALE_FILES[*]}")
  fail "Stale fault injection state files found: ${FILE_LIST}"
fi

echo ""

# ===========================================================================
# Summary
# ===========================================================================
if [[ $FAILED -eq 0 && $WARNED -eq 0 ]]; then
  echo -e "${GREEN}=== Result: ${PASSED}/${TOTAL} checks passed — READY FOR DEMO ===${RESET}"
  exit 0
elif [[ $FAILED -eq 0 ]]; then
  echo -e "${YELLOW}=== Result: ${PASSED}/${TOTAL} checks passed, ${WARNED} warning(s) — REVIEW WARNINGS ===${RESET}"
  exit 0
else
  echo -e "${RED}=== Result: ${PASSED}/${TOTAL} checks passed, ${FAILED} failed — NOT READY FOR DEMO ===${RESET}"
  exit 1
fi
