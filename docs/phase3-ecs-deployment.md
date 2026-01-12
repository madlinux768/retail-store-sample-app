# Phase 3: ECS Managed Instances Deployment

## Overview

Deploy the retail store application to Amazon ECS using **ECS Managed Instances** for compute, enabling evaluation of AWS DevOps Agent and AWS Security Agent.

## What Was Created

### Terraform Module (`terraform/ecs/managed-instances/`)
- **ECS Cluster** with Container Insights
- **Managed Instances Capacity Provider** with auto-scaling
- **5 ECS Services** using EC2 launch type
- **Application Load Balancer** for public access
- **Service Module** for reusable task/service definitions
- **IAM Roles** (infrastructure role, instance profile)
- **Security Groups** with least privilege
- **Service Connect** for service-to-service communication

### GitHub Actions Workflow (`.github/workflows/deploy-ecs.yml`)
- **Terraform plan/apply** automation
- **Environment protection** (dev/staging/prod)
- **Health checks** after deployment
- **Manual approval** for production

### AWS Resources Created
- VPC with public/private subnets (3 AZs)
- ECS cluster with Managed Instances
- RDS (PostgreSQL + MySQL)
- DynamoDB table
- ElastiCache (Redis)
- Amazon MQ (RabbitMQ)
- Application Load Balancer
- CloudWatch log groups

## Deployment Steps

### Step 1: Configure Backend

Create `terraform/ecs/managed-instances/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "retail-store-terraform-state-173471018689"
    key            = "ecs/managed-instances/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }
}
```

### Step 2: Configure Variables

Copy and customize:

```bash
cp terraform/ecs/managed-instances/terraform.tfvars.example \
   terraform/ecs/managed-instances/terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
container_image_repository = "173471018689.dkr.ecr.us-west-2.amazonaws.com/retail-store"
container_image_tag        = "6d9f12c"  # Use specific commit SHA
```

### Step 3: Deploy via GitHub Actions

1. Go to Actions tab → "Deploy to ECS Managed Instances"
2. Click "Run workflow"
3. Select:
   - **Environment**: dev
   - **Image tag**: latest (or specific commit SHA)
   - **Auto approve**: false (for first deployment)
4. Click "Run workflow"

The workflow will:
- Run `terraform plan`
- Wait for manual approval (if not auto-approved)
- Run `terraform apply`
- Perform health checks
- Output application URL

### Step 4: Manual Deployment (Alternative)

```bash
cd terraform/ecs/managed-instances

# Initialize
terraform init

# Plan
terraform plan -var="container_image_tag=latest"

# Apply
terraform apply -var="container_image_tag=latest"

# Get URL
terraform output -raw application_url
```

## Verification

### Check Cluster Status

```bash
aws ecs describe-clusters \
  --clusters retail-store-ecs-mi-cluster \
  --region us-west-2
```

### Check Capacity Provider

```bash
aws ecs describe-capacity-providers \
  --capacity-providers retail-store-ecs-mi-managed-instances \
  --region us-west-2 \
  --query 'capacityProviders[0].{name:name,status:status,managedScaling:managedInstanceScaling}'
```

### Check Container Instances

```bash
aws ecs list-container-instances \
  --cluster retail-store-ecs-mi-cluster \
  --region us-west-2

# Get details
aws ecs describe-container-instances \
  --cluster retail-store-ecs-mi-cluster \
  --container-instances <instance-id> \
  --region us-west-2
```

### Check Services

```bash
aws ecs list-services \
  --cluster retail-store-ecs-mi-cluster \
  --region us-west-2

# Check service health
aws ecs describe-services \
  --cluster retail-store-ecs-mi-cluster \
  --services ui catalog cart orders checkout \
  --region us-west-2 \
  --query 'services[*].[serviceName,runningCount,desiredCount,status]'
```

### Access Application

```bash
# Get URL from Terraform
terraform output -raw application_url

# Or get ALB DNS directly
aws elbv2 describe-load-balancers \
  --names retail-store-ecs-mi-alb \
  --region us-west-2 \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

## ECS Managed Instances Benefits

### vs Fargate
- ✅ **Cost**: ~40% cheaper for steady workloads
- ✅ **Control**: Access to instance types, GPUs, specialized hardware
- ✅ **Density**: Multiple tasks per instance
- ✅ **Networking**: Advanced networking capabilities
- ❌ **Management**: AWS handles patching but you see instances

### Key Features
- **Auto-scaling**: 2-10 instances based on demand
- **Auto-patching**: 14-day patch cycle with graceful draining
- **Multi-task placement**: Optimizes instance utilization
- **Instance diversity**: t3.medium and t3a.medium for cost optimization
- **Container Insights**: Enhanced monitoring
- **ECS Exec**: Secure container access without SSH

## Monitoring & Observability

### CloudWatch Container Insights

View in AWS Console:
- CloudWatch → Container Insights → ECS Clusters
- Select: retail-store-ecs-mi-cluster

Metrics available:
- CPU and memory utilization
- Network traffic
- Task and service counts
- Container instance health

### CloudWatch Logs

```bash
# Tail all service logs
aws logs tail retail-store-ecs-mi-tasks \
  --follow \
  --region us-west-2

# Filter by service
aws logs tail retail-store-ecs-mi-tasks \
  --follow \
  --filter-pattern "checkout" \
  --region us-west-2
```

### ECS Exec (SSH Alternative)

```bash
# List tasks
aws ecs list-tasks \
  --cluster retail-store-ecs-mi-cluster \
  --service-name ui \
  --region us-west-2

# Execute command in container
aws ecs execute-command \
  --cluster retail-store-ecs-mi-cluster \
  --task <task-id> \
  --container ui-service \
  --interactive \
  --command "/bin/sh" \
  --region us-west-2
```

## Updating Deployments

### Deploy New Image Tag

Via GitHub Actions:
1. Trigger "Deploy to ECS Managed Instances" workflow
2. Specify new image tag (e.g., commit SHA)
3. Workflow updates task definitions and services

Via Terraform:
```bash
terraform apply -var="container_image_tag=abc1234"
```

### Force New Deployment

```bash
aws ecs update-service \
  --cluster retail-store-ecs-mi-cluster \
  --service ui \
  --force-new-deployment \
  --region us-west-2
```

## Cost Optimization

### Current Configuration
- **3x t3.medium instances**: ~$75/month
- **Auto-scaling**: Scales down to 2 instances when idle
- **Lifecycle policies**: Old images automatically deleted
- **Spot instances**: Not enabled (can add for 70% savings)

### Enable Spot Instances (Optional)

Add to capacity provider configuration:
```hcl
managed_instance_requirements {
  instance_types = ["t3.medium", "t3a.medium"]
  spot_enabled   = true  # Add this
}
```

## Troubleshooting

### Services Stuck in PENDING

Check events:
```bash
aws ecs describe-services \
  --cluster retail-store-ecs-mi-cluster \
  --services <service-name> \
  --region us-west-2 \
  --query 'services[0].events[0:5]'
```

Common causes:
- Insufficient capacity (instances not launched)
- Image pull errors (ECR permissions)
- Health check failures
- Security group misconfiguration

### No Container Instances

Check capacity provider status:
```bash
aws ecs describe-capacity-providers \
  --capacity-providers retail-store-ecs-mi-managed-instances \
  --region us-west-2
```

Verify IAM roles:
- Infrastructure role has correct permissions
- Instance profile attached to capacity provider

### Image Pull Errors

Verify ECR access:
```bash
# Check if images exist
aws ecr describe-images \
  --repository-name retail-store-ui \
  --region us-west-2

# Check instance profile has ECR read permissions
aws iam get-role-policy \
  --role-name retail-store-ecs-mi-ecs-instance \
  --policy-name AmazonEC2ContainerRegistryReadOnly
```

## Security Considerations

### Network Security
- ✅ Services in private subnets
- ✅ ALB in public subnets
- ✅ Security groups with minimal access
- ✅ No direct internet access to services

### IAM Security
- ✅ Separate execution and task roles
- ✅ Least privilege permissions
- ✅ Instance profile for EC2 instances
- ✅ Infrastructure role for ECS management

### Data Security
- ✅ Secrets in Secrets Manager
- ✅ RDS encryption at rest
- ✅ DynamoDB encryption
- ✅ CloudWatch logs encrypted

## Next Steps

After successful deployment:

1. **Configure AWS DevOps Agent**
   - Create Agent Space
   - Connect to ECS cluster
   - Set up CloudWatch integration
   - Configure Slack notifications

2. **Configure AWS Security Agent**
   - Create Security Agent Space
   - Define security requirements
   - Connect GitHub repository
   - Run initial security assessment

3. **Enable GuardDuty Runtime Monitoring**
   - Enable for ECS
   - Configure threat detection
   - Set up alerting

4. **Test and Evaluate**
   - Make code changes
   - Trigger deployments
   - Simulate incidents
   - Run penetration tests
   - Evaluate agent responses

## Cleanup

To destroy all resources:

```bash
cd terraform/ecs/managed-instances
terraform destroy
```

**Warning**: This deletes all data including databases!

## References

- [ECS Managed Instances Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ManagedInstances.html)
- [AWS DevOps Agent](https://docs.aws.amazon.com/devopsagent/latest/userguide/)
- [AWS Security Agent](https://docs.aws.amazon.com/securityagent/latest/userguide/)
