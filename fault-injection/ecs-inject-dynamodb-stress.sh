#!/bin/bash
# ECS Lab 4: DynamoDB Stress
# Launches a one-off Fargate task that hammers the carts DynamoDB table with
# concurrent scans, queries, and GetItem calls to trigger throttle alarms.
set -e

export AWS_REGION="${AWS_REGION:-us-west-2}"
CLUSTER_NAME="${CLUSTER_NAME:-retail-store-ecs-cluster}"
ENV_NAME="${ENV_NAME:-retail-store-ecs}"
TABLE_NAME="${TABLE_NAME:-retail-store-ecs-carts}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ECS Lab 4: DynamoDB Stress Injection ==="
echo ""

echo "[1/3] Discovering network configuration from carts service..."
NETWORK_CONFIG=$(AWS_PAGER="" aws ecs describe-services --cluster "$CLUSTER_NAME" --services carts \
  --region "$AWS_REGION" --query "services[0].networkConfiguration.awsvpcConfiguration" --output json)

SUBNETS=$(echo "$NETWORK_CONFIG" | jq -r '.subnets[0]')
SECURITY_GROUP=$(echo "$NETWORK_CONFIG" | jq -r '.securityGroups[0]')
TASK_ROLE=$(AWS_PAGER="" aws ecs describe-task-definition --task-definition "${ENV_NAME}-carts" \
  --region "$AWS_REGION" --query "taskDefinition.taskRoleArn" --output text)
EXEC_ROLE=$(AWS_PAGER="" aws ecs describe-task-definition --task-definition "${ENV_NAME}-carts" \
  --region "$AWS_REGION" --query "taskDefinition.executionRoleArn" --output text)

echo "  Subnet: $SUBNETS"
echo "  Security Group: $SECURITY_GROUP"
echo "  Task Role: $TASK_ROLE"

echo ""
echo "[2/3] Registering stress test task definition..."

STRESS_TASK_DEF=$(cat <<EOF
{
  "family": "${ENV_NAME}-dynamodb-stress",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "taskRoleArn": "$TASK_ROLE",
  "executionRoleArn": "$EXEC_ROLE",
  "containerDefinitions": [
    {
      "name": "stress",
      "image": "public.ecr.aws/docker/library/python:3.11-slim",
      "essential": true,
      "command": ["python3", "-c", "import boto3, threading, time, random, string, os\ntable_name = os.environ['TABLE_NAME']\nregion = os.environ['AWS_REGION']\nddb = boto3.resource('dynamodb', region_name=region)\ntable = ddb.Table(table_name)\ndef scan_worker():\n    while True:\n        try:\n            table.scan(Limit=1000)\n        except Exception as e:\n            print(f'Scan error: {e}')\n        time.sleep(0.1)\ndef query_worker():\n    while True:\n        try:\n            table.query(IndexName='idx_global_customerId', KeyConditionExpression=boto3.dynamodb.conditions.Key('customerId').eq(f'stress-{random.randint(1,1000)}'))\n        except Exception as e:\n            print(f'Query error: {e}')\n        time.sleep(0.1)\ndef write_worker():\n    while True:\n        try:\n            table.put_item(Item={'id': f'stress-{random.randint(1,100000)}', 'customerId': f'stress-{random.randint(1,1000)}', 'items': [{'id': ''.join(random.choices(string.ascii_letters, k=100))} for _ in range(10)]})\n        except Exception as e:\n            print(f'Write error: {e}')\n        time.sleep(0.05)\nthreads = []\nfor _ in range(20):\n    threads.append(threading.Thread(target=scan_worker, daemon=True))\nfor _ in range(20):\n    threads.append(threading.Thread(target=query_worker, daemon=True))\nfor _ in range(30):\n    threads.append(threading.Thread(target=write_worker, daemon=True))\nfor t in threads:\n    t.start()\nprint(f'Stress test running: 20 scan + 20 query + 30 write threads against {table_name}')\nwhile True:\n    time.sleep(60)\n    print('Still running...')"],
      "environment": [
        {"name": "TABLE_NAME", "value": "$TABLE_NAME"},
        {"name": "AWS_REGION", "value": "$AWS_REGION"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/retail-store-ecs",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "dynamodb-stress"
        }
      }
    }
  ]
}
EOF
)

AWS_PAGER="" aws ecs register-task-definition --cli-input-json "$STRESS_TASK_DEF" \
  --region "$AWS_REGION" > /dev/null
echo "  Registered: ${ENV_NAME}-dynamodb-stress"

echo ""
echo "[3/3] Launching stress task..."
TASK_ARN=$(AWS_PAGER="" aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "${ENV_NAME}-dynamodb-stress" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --region "$AWS_REGION" \
  --query "tasks[0].taskArn" --output text)

echo "  Task launched: $TASK_ARN"
echo "$TASK_ARN" > "$SCRIPT_DIR/ecs-dynamodb-stress-task.txt"

echo ""
echo "=== Fault Injection Active ==="
echo ""
echo "Injected: 70 concurrent threads (20 scan + 20 query + 30 write) against $TABLE_NAME"
echo ""
echo "Expected alarms (within 5-10 minutes):"
echo "  1. retail-store-ecs-dynamodb-write-throttles"
echo "  2. retail-store-ecs-dynamodb-read-throttles"
echo "  3. retail-store-ecs-dynamodb-latency-high"
echo ""
echo "Rollback: ./fault-injection/ecs-rollback-dynamodb-stress.sh"
