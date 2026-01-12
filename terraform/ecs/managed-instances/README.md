# ECS Managed Instances Deployment

Deploys the AWS Containers Retail Sample application to Amazon ECS using **ECS Managed Instances** for compute.

## What This Creates

- **VPC** with public and private subnets across 3 AZs
- **ECS Cluster** with Container Insights enabled
- **ECS Managed Instances** capacity provider with auto-scaling
- **5 ECS Services** (ui, catalog, cart, orders, checkout)
- **Application Load Balancer** for UI access
- **RDS** (PostgreSQL for orders, MySQL for catalog)
- **DynamoDB** table for cart
- **ElastiCache** (Redis) for checkout
- **Amazon MQ** (RabbitMQ) for orders messaging
- **CloudWatch** logs and monitoring

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- ECR repositories with container images
- Bootstrap infrastructure deployed (S3 backend, IAM role)

## Configuration

Create `terraform.tfvars`:

```hcl
environment_name           = "retail-store-ecs-mi"
aws_region                 = "us-west-2"
container_image_repository = "173471018689.dkr.ecr.us-west-2.amazonaws.com/retail-store"
container_image_tag        = "latest"
container_insights_setting = "enhanced"
opentelemetry_enabled      = false

# Instance configuration
instance_types = ["t3.medium", "t3a.medium"]
min_size       = 2
max_size       = 10
desired_size   = 3
```

## Deployment

```bash
cd terraform/ecs/managed-instances

# Initialize with remote backend
terraform init

# Review the plan
terraform plan

# Deploy (takes ~15-20 minutes)
terraform apply
```

## Access the Application

```bash
# Get the application URL
terraform output -raw application_url

# Example: http://retail-store-ecs-mi-alb-1234567890.us-west-2.elb.amazonaws.com
```

## ECS Managed Instances Features

- **Auto-scaling**: Scales from 2-10 instances based on demand
- **Auto-patching**: Instances automatically patched every 14 days
- **Cost optimization**: Multiple tasks per instance
- **Instance types**: t3.medium and t3a.medium (cost-effective)
- **Container Insights**: Enhanced monitoring enabled
- **ECS Exec**: SSH-less access to containers

## Monitoring

### View Services

```bash
aws ecs list-services \
  --cluster retail-store-ecs-mi-cluster \
  --region us-west-2
```

### View Tasks

```bash
aws ecs list-tasks \
  --cluster retail-store-ecs-mi-cluster \
  --region us-west-2
```

### View Container Instances

```bash
aws ecs list-container-instances \
  --cluster retail-store-ecs-mi-cluster \
  --region us-west-2
```

### Access Container Logs

```bash
aws logs tail retail-store-ecs-mi-tasks \
  --follow \
  --region us-west-2
```

## Cost Estimate

**Monthly costs** (approximate):
- ECS Managed Instances (3x t3.medium): ~$75
- RDS (2x db.t3.micro): ~$30
- DynamoDB (on-demand): ~$10
- ElastiCache (cache.t3.micro): ~$15
- Amazon MQ (mq.t3.micro): ~$25
- ALB: ~$20
- Data transfer & CloudWatch: ~$15
- **Total**: ~$190/month

## Security Features

✅ Private subnets for all services  
✅ Security groups with least privilege  
✅ Secrets stored in Secrets Manager  
✅ Encrypted data at rest (RDS, DynamoDB)  
✅ IAM roles with minimal permissions  
✅ No SSH access to instances  
✅ ECS Exec for secure container access  

## Cleanup

```bash
terraform destroy
```

Note: This will delete all resources including databases. Data will be lost.

## Troubleshooting

### Services not starting

Check service events:
```bash
aws ecs describe-services \
  --cluster retail-store-ecs-mi-cluster \
  --services ui catalog cart orders checkout \
  --region us-west-2 \
  --query 'services[*].[serviceName,events[0].message]'
```

### Container instances not launching

Check capacity provider:
```bash
aws ecs describe-capacity-providers \
  --capacity-providers retail-store-ecs-mi-managed-instances \
  --region us-west-2
```

### Image pull errors

Verify ECR permissions and image exists:
```bash
aws ecr describe-images \
  --repository-name retail-store-ui \
  --region us-west-2
```

## Next Steps

After deployment:
1. Configure AWS DevOps Agent Space
2. Configure AWS Security Agent Space
3. Set up GuardDuty Runtime Monitoring
4. Run penetration tests
5. Simulate incidents for agent evaluation
