# AWS Containers Retail Sample - DevOps Agent Runbook

## Application Overview

**Name**: AWS Containers Retail Sample  
**Purpose**: Educational microservices application demonstrating container platforms  
**Architecture**: Polyglot microservices on ECS Managed Instances  
**Region**: us-west-2  
**Environment**: retail-store-ecs-mi  

## Service Topology

### Microservices Architecture

```
Internet → ALB → UI Service → {Catalog, Cart, Checkout, Orders}
                                    ↓         ↓         ↓
                                  MySQL   DynamoDB   Redis
                                                      ↓
                                                   Orders → PostgreSQL + RabbitMQ
```

### Service Dependencies

**UI Service** (Java/Spring Boot)
- **Depends on**: Catalog, Cart, Checkout, Orders (all via HTTP)
- **Exposed**: Public via ALB on port 80
- **Internal**: Port 8080
- **Health**: `/actuator/health`
- **Purpose**: Web frontend, aggregates data from all backend services

**Catalog Service** (Go/Gin)
- **Depends on**: MySQL (RDS Aurora)
- **Exposed**: Internal only via Service Connect
- **Port**: 8080
- **Health**: `/health`
- **Purpose**: Product catalog API, read-heavy workload

**Cart Service** (Java/Spring Boot)
- **Depends on**: DynamoDB table `retail-store-ecs-mi-carts`
- **Exposed**: Internal only via Service Connect
- **Port**: 8080
- **Health**: `/actuator/health`
- **Purpose**: Shopping cart management, stateful

**Orders Service** (Java/Spring Boot)
- **Depends on**: PostgreSQL (RDS Aurora), RabbitMQ (Amazon MQ)
- **Exposed**: Internal only via Service Connect
- **Port**: 8080
- **Health**: `/actuator/health`
- **Purpose**: Order processing, event-driven with RabbitMQ

**Checkout Service** (Node.js/NestJS)
- **Depends on**: Redis (ElastiCache), Orders service
- **Exposed**: Internal only via Service Connect
- **Port**: 8080
- **Health**: `/health`
- **Purpose**: Checkout orchestration, session management

## Infrastructure Components

### ECS Cluster
- **Name**: `retail-store-ecs-mi-cluster`
- **Type**: ECS Managed Instances (EC2 launch type)
- **Capacity Provider**: `retail-store-ecs-mi-managed-instances`
- **Instance Types**: t3.medium, t3a.medium
- **Scaling**: 2-10 instances, target 80% capacity
- **Container Insights**: Enhanced mode enabled

### Networking
- **VPC**: 3 AZs with public and private subnets
- **Service Connect**: Enabled for service-to-service communication
- **Service Discovery**: `retailstore.local` namespace
- **ALB**: `retail-store-ecs-mi-alb` (public-facing)

### Data Stores
- **Catalog DB**: RDS Aurora MySQL, endpoint in `DB_ENDPOINT` env var
- **Orders DB**: RDS Aurora PostgreSQL, endpoint in `SPRING_DATASOURCE_URL`
- **Cart DB**: DynamoDB table, name in `CARTS_DYNAMODB_TABLENAME`
- **Checkout Cache**: ElastiCache Redis, endpoint in `REDIS_URL`
- **Orders Queue**: Amazon MQ RabbitMQ, endpoint in `SPRING_RABBITMQ_HOST`

### Observability
- **Logs**: CloudWatch log group `retail-store-ecs-mi-tasks`
- **Metrics**: Container Insights (CPU, memory, network)
- **Tracing**: OpenTelemetry (if enabled)
- **Health Checks**: All services expose health endpoints

## Common Failure Scenarios

### Service Unavailable / 503 Errors

**Symptoms**: UI returns 503, ALB health checks failing

**Investigation Steps**:
1. Check ECS service status: `aws ecs describe-services --cluster retail-store-ecs-mi-cluster --services ui`
2. Check task count: running vs desired
3. Check task health: `aws ecs describe-tasks --cluster retail-store-ecs-mi-cluster --tasks <task-arn>`
4. Check CloudWatch logs for startup errors
5. Verify container image exists in ECR
6. Check security group rules allow ALB → ECS traffic

**Common Causes**:
- Image pull failure (ECR permissions, image doesn't exist)
- Health check failing (application not starting)
- Insufficient capacity (no container instances available)
- Database connection failure

**Resolution**:
- If image missing: Trigger GitHub Actions "Build and Push Container Images"
- If health check failing: Check logs for application errors
- If no capacity: Check capacity provider scaling
- If DB connection: Verify security groups, credentials

### Backend Service Communication Failure

**Symptoms**: UI loads but shows errors loading products/cart/orders

**Investigation Steps**:
1. Check Service Connect configuration: All services should be registered
2. Check backend service health: `aws ecs describe-services --cluster retail-store-ecs-mi-cluster --services catalog cart orders checkout`
3. Check CloudWatch logs for connection errors
4. Verify Service Discovery namespace: `aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=<namespace-id>`
5. Check security groups allow inter-service traffic

**Common Causes**:
- Backend service not running (0 tasks)
- Service Connect misconfigured
- DNS resolution failing
- Security groups blocking traffic
- Backend service crashed/restarting

**Resolution**:
- Restart failed service: `aws ecs update-service --cluster retail-store-ecs-mi-cluster --service <name> --force-new-deployment`
- Check service logs for errors
- Verify environment variables point to correct endpoints

### Database Connection Failures

**Symptoms**: Service logs show database connection errors, tasks crash-looping

**Investigation Steps**:
1. Check RDS cluster status: `aws rds describe-db-clusters --db-cluster-identifier <cluster-id>`
2. Verify security groups allow ECS → RDS traffic
3. Check database credentials in environment variables
4. Check RDS CloudWatch metrics (connections, CPU)
5. Verify database endpoint is reachable from ECS

**Common Causes**:
- RDS cluster stopped/unavailable
- Security group rules missing
- Wrong credentials
- Connection pool exhausted
- Database out of storage

**Resolution**:
- Start RDS if stopped
- Add security group rule: ECS security group → RDS port
- Verify credentials match RDS master password
- Scale RDS instance if resource constrained

### DynamoDB Throttling (Cart Service)

**Symptoms**: Cart operations slow/failing, DynamoDB throttling errors in logs

**Investigation Steps**:
1. Check DynamoDB metrics: `aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name UserErrors`
2. Check table capacity mode: `aws dynamodb describe-table --table-name retail-store-ecs-mi-carts`
3. Check IAM permissions for cart service task role
4. Review cart service logs for throttling exceptions

**Common Causes**:
- On-demand capacity exceeded
- IAM permissions missing
- Hot partition key
- Burst capacity exhausted

**Resolution**:
- Table is on-demand, should auto-scale
- Verify task role has DynamoDB permissions
- Check for hot keys in access patterns

### Redis Connection Issues (Checkout Service)

**Symptoms**: Checkout fails, Redis connection errors

**Investigation Steps**:
1. Check ElastiCache cluster status: `aws elasticache describe-cache-clusters --cache-cluster-id <id>`
2. Verify security groups allow ECS → ElastiCache traffic
3. Check Redis endpoint in `REDIS_URL` environment variable
4. Check ElastiCache CloudWatch metrics

**Common Causes**:
- ElastiCache node unavailable
- Security group rules missing
- Wrong endpoint
- Redis out of memory

**Resolution**:
- Verify ElastiCache cluster is available
- Add security group rule if missing
- Check Redis memory usage, scale if needed

### RabbitMQ Connection Issues (Orders Service)

**Symptoms**: Orders not processing, RabbitMQ connection errors

**Investigation Steps**:
1. Check Amazon MQ broker status: `aws mq describe-broker --broker-id <id>`
2. Verify security groups allow ECS → MQ traffic
3. Check MQ credentials in environment variables
4. Check MQ CloudWatch metrics (connections, messages)

**Common Causes**:
- MQ broker stopped/rebooting
- Security group rules missing
- Wrong credentials
- Queue full/disk space

**Resolution**:
- Verify MQ broker is running
- Add security group rule if missing
- Check queue depths, purge if needed

### Container Instance Issues

**Symptoms**: Tasks pending, not enough capacity

**Investigation Steps**:
1. Check container instances: `aws ecs list-container-instances --cluster retail-store-ecs-mi-cluster`
2. Check capacity provider: `aws ecs describe-capacity-providers --capacity-providers retail-store-ecs-mi-managed-instances`
3. Check EC2 instances: Look for instances with tag `AmazonECSManaged=true`
4. Check IAM roles: infrastructure role and instance profile

**Common Causes**:
- Capacity provider not scaling
- IAM permissions missing
- EC2 service limits reached
- Subnet IP exhaustion

**Resolution**:
- Verify infrastructure role has correct permissions
- Check EC2 limits in Service Quotas
- Manually scale if needed: Update capacity provider settings

## Deployment Information

### Container Images
- **Registry**: `173471018689.dkr.ecr.us-west-2.amazonaws.com`
- **Repositories**: `retail-store-{ui,catalog,cart,orders,checkout}`
- **Tags**: Commit SHA (7 chars), `latest`, timestamp
- **Build**: GitHub Actions workflow "Build and Push Container Images"

### Deployment Process
- **Method**: GitHub Actions workflow "Deploy to ECS Managed Instances"
- **Trigger**: Manual (workflow_dispatch)
- **Terraform**: Manages all infrastructure
- **State**: S3 bucket `retail-store-terraform-state-173471018689`
- **Rollback**: Redeploy previous image tag via workflow

### Configuration Management
- **Environment Variables**: Defined in Terraform service modules
- **Secrets**: Database passwords from RDS, MQ passwords
- **Service Discovery**: Via Service Connect DNS names

## Monitoring & Alerting

### Key Metrics to Monitor

**ECS Cluster**:
- Container instance count (should be 2-10)
- CPU/Memory utilization (target 80%)
- Task placement failures

**Services**:
- Running task count vs desired (should match)
- Task start/stop rate (high churn indicates issues)
- Health check failures

**Application**:
- ALB target health (UI service)
- HTTP 5xx error rate
- Response time (p50, p95, p99)

**Dependencies**:
- RDS connections, CPU, storage
- DynamoDB consumed capacity, throttles
- ElastiCache CPU, memory, evictions
- MQ connections, queue depth

### CloudWatch Log Insights Queries

**Find errors across all services**:
```
fields @timestamp, @message
| filter @message like /ERROR|Exception|Failed/
| sort @timestamp desc
| limit 100
```

**Service-specific errors**:
```
fields @timestamp, @message
| filter @logStream like /catalog/
| filter @message like /ERROR/
| sort @timestamp desc
```

**Slow requests**:
```
fields @timestamp, @message
| filter @message like /duration/
| parse @message /duration=(?<duration>\d+)/
| filter duration > 1000
| sort duration desc
```

## Incident Response Procedures

### Service Down
1. Check service status in ECS
2. Check recent deployments (GitHub Actions)
3. Check CloudWatch logs for errors
4. Check dependencies (DB, cache, queue)
5. Force new deployment if needed
6. Rollback to previous image tag if deployment caused issue

### High Error Rate
1. Check CloudWatch logs for error patterns
2. Check recent code changes (GitHub commits)
3. Check dependency health
4. Check resource constraints (CPU, memory)
5. Scale services if resource-constrained
6. Rollback if recent deployment caused issue

### Performance Degradation
1. Check Container Insights for resource utilization
2. Check database performance (RDS metrics)
3. Check cache hit rate (ElastiCache)
4. Check for hot partitions (DynamoDB)
5. Scale ECS services or databases as needed

### Deployment Failure
1. Check GitHub Actions workflow logs
2. Check Terraform plan/apply output
3. Check IAM permissions
4. Check resource limits (EC2, RDS, etc.)
5. Check for resource conflicts (naming, security groups)

## Useful AWS CLI Commands

### ECS Operations
```bash
# List all services
aws ecs list-services --cluster retail-store-ecs-mi-cluster --region us-west-2

# Describe service health
aws ecs describe-services --cluster retail-store-ecs-mi-cluster --services ui --region us-west-2

# List tasks
aws ecs list-tasks --cluster retail-store-ecs-mi-cluster --service-name ui --region us-west-2

# Get task details
aws ecs describe-tasks --cluster retail-store-ecs-mi-cluster --tasks <task-arn> --region us-west-2

# Force new deployment
aws ecs update-service --cluster retail-store-ecs-mi-cluster --service ui --force-new-deployment --region us-west-2

# Scale service
aws ecs update-service --cluster retail-store-ecs-mi-cluster --service ui --desired-count 3 --region us-west-2

# Execute command in container
aws ecs execute-command --cluster retail-store-ecs-mi-cluster --task <task-arn> --container ui --interactive --command "/bin/sh" --region us-west-2
```

### CloudWatch Logs
```bash
# Tail logs
aws logs tail retail-store-ecs-mi-tasks --follow --region us-west-2

# Filter by service
aws logs tail retail-store-ecs-mi-tasks --follow --filter-pattern "catalog" --region us-west-2

# Query logs
aws logs start-query --log-group-name retail-store-ecs-mi-tasks --start-time $(date -u -d '1 hour ago' +%s) --end-time $(date -u +%s) --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20' --region us-west-2
```

### Database Operations
```bash
# Check RDS cluster status
aws rds describe-db-clusters --region us-west-2 --query 'DBClusters[?contains(DBClusterIdentifier, `retail-store`)].{Name:DBClusterIdentifier,Status:Status,Endpoint:Endpoint}'

# Check DynamoDB table
aws dynamodb describe-table --table-name retail-store-ecs-mi-carts --region us-west-2

# Check ElastiCache
aws elasticache describe-cache-clusters --region us-west-2 --query 'CacheClusters[?contains(CacheClusterId, `retail-store`)].{Name:CacheClusterId,Status:CacheClusterStatus,Endpoint:CacheNodes[0].Endpoint.Address}'

# Check Amazon MQ
aws mq list-brokers --region us-west-2 --query 'BrokerSummaries[?contains(BrokerName, `retail-store`)].{Name:BrokerName,Status:BrokerState,Endpoint:BrokerArn}'
```

## Application-Specific Context

### Technology Stack
- **UI, Cart, Orders**: Java 21, Spring Boot 3.5.x, Maven
- **Catalog**: Go 1.23+, Gin framework
- **Checkout**: Node.js 20, NestJS 11.x

### Build System
- **Monorepo**: Nx workspace
- **Container Registry**: Amazon ECR Private
- **CI/CD**: GitHub Actions
- **IaC**: Terraform with S3 backend

### Known Limitations
- **Not production-ready**: Educational demo application
- **Single NAT Gateway**: Cost optimization, single point of failure
- **No auto-scaling**: Services have fixed desired count of 2
- **No circuit breakers**: Services don't implement fallback patterns
- **Synchronous calls**: UI blocks on backend service calls

### Expected Behavior
- **UI Load Time**: 2-5 seconds (aggregates data from 4 services)
- **Catalog Response**: < 500ms (database queries)
- **Cart Operations**: < 200ms (DynamoDB)
- **Checkout**: < 1s (Redis + Orders service call)
- **Order Creation**: 1-3s (database write + RabbitMQ publish)

## Troubleshooting Decision Tree

### If UI is down:
1. Check ALB target health
2. Check UI service task count
3. Check UI service logs
4. Check recent deployments

### If UI loads but shows errors:
1. Identify which backend service is failing (check browser console/network tab)
2. Check that specific backend service health
3. Check Service Connect DNS resolution
4. Check backend service logs

### If specific backend service is down:
1. Check service task count
2. Check service logs for startup errors
3. Check dependency health (database, cache, queue)
4. Check security groups
5. Check IAM permissions

### If database connection fails:
1. Check RDS cluster status
2. Check security group rules
3. Verify credentials
4. Check connection pool settings
5. Check RDS CloudWatch metrics

### If performance is degraded:
1. Check Container Insights for resource constraints
2. Check database performance metrics
3. Check cache hit rates
4. Check for error spikes in logs
5. Check for recent deployments

## Mitigation Strategies

### Quick Fixes
- **Force new deployment**: Restarts all tasks with current configuration
- **Scale up**: Increase desired task count temporarily
- **Rollback**: Deploy previous known-good image tag
- **Restart dependency**: Reboot RDS, flush Redis, restart MQ

### Preventative Actions
- **Enable auto-scaling**: Add target tracking policies
- **Add circuit breakers**: Implement fallback responses
- **Add caching**: Reduce database load
- **Add retries**: Handle transient failures
- **Add rate limiting**: Protect backend services

## Deployment Rollback Procedure

1. Identify last known-good image tag from ECR
2. Trigger "Deploy to ECS Managed Instances" workflow
3. Specify previous image tag
4. Monitor deployment progress
5. Verify application health

## Contact & Escalation

**GitHub Repository**: https://github.com/madlinux768/retail-store-sample-app  
**AWS Account**: 173471018689  
**Region**: us-west-2  
**Terraform State**: S3 bucket `retail-store-terraform-state-173471018689`

## Agent-Specific Instructions

### When Investigating Incidents

1. **Start with symptoms**: What is the user experiencing?
2. **Check service health**: ECS service status and task counts
3. **Review recent changes**: GitHub commits, deployments, infrastructure changes
4. **Analyze logs**: CloudWatch logs for error patterns
5. **Check dependencies**: Database, cache, queue health
6. **Correlate metrics**: Container Insights, RDS, DynamoDB metrics
7. **Identify root cause**: Single point of failure or cascading issue
8. **Provide mitigation**: Specific AWS CLI commands or Terraform changes
9. **Suggest prevention**: Long-term improvements to prevent recurrence

### When Providing Recommendations

- **Be specific**: Provide exact AWS CLI commands with resource names
- **Consider dependencies**: Changes may affect multiple services
- **Prioritize safety**: Suggest testing in non-prod first
- **Include validation**: How to verify the fix worked
- **Think holistically**: Consider cost, security, reliability

### Context You Have Access To

- **CloudWatch Logs**: All service logs in `retail-store-ecs-mi-tasks`
- **CloudWatch Metrics**: Container Insights, RDS, DynamoDB, ElastiCache, MQ
- **ECS API**: Cluster, services, tasks, container instances
- **GitHub**: Repository, commits, Actions workflows
- **Terraform State**: Infrastructure configuration and relationships

### What You Should Know

- This is a **demo application** for agent evaluation
- **Cost optimization** is important (single NAT, small instances)
- **Reliability** is more important than performance
- **Security** follows AWS best practices (private subnets, security groups, IAM)
- **Observability** is comprehensive (logs, metrics, tracing)

## Success Criteria

An incident is resolved when:
1. All ECS services show desired task count = running task count
2. All health checks passing
3. UI accessible via ALB and loads without errors
4. No error spikes in CloudWatch logs
5. All dependencies (RDS, DynamoDB, ElastiCache, MQ) healthy
6. Response times within expected ranges

## Additional Resources

- **Application Documentation**: `/docs` directory in repository
- **Terraform Modules**: `/terraform/ecs/managed-instances`
- **Service Code**: `/src/{service}` directories
- **GitHub Actions**: `/.github/workflows`
