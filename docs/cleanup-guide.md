# Cleanup Guide - Removing Deployed Resources

This guide explains how to safely remove all AWS resources created during the deployment phases.

## Overview

Resources are organized in three layers:
1. **ECS Infrastructure** (Phase 3) - Most expensive, ~$190/month
2. **ECR Repositories** (Phase 2) - Minimal cost, ~$5-15/month
3. **Bootstrap Infrastructure** (Phase 1) - Minimal cost, ~$5/month

## Recommended Cleanup Order

Always destroy in reverse order of creation to avoid dependency issues.

### Step 1: Destroy ECS Infrastructure (Phase 3)

This removes the application and all supporting services.

#### Option A: Via Terraform (Recommended)

```bash
cd terraform/ecs/managed-instances

# Initialize if needed
terraform init

# Review what will be destroyed
terraform plan -destroy \
  -var="container_image_repository=173471018689.dkr.ecr.us-west-2.amazonaws.com/retail-store"

# Destroy all resources
terraform destroy \
  -var="container_image_repository=173471018689.dkr.ecr.us-west-2.amazonaws.com/retail-store"

# Type 'yes' when prompted
```

**Time**: 15-20 minutes  
**Resources Deleted**: 148 resources including:
- ECS cluster and services
- Container instances
- RDS clusters (2)
- DynamoDB table
- ElastiCache cluster
- Amazon MQ broker
- Application Load Balancer
- VPC and networking
- Security groups
- IAM roles
- CloudWatch log groups

#### Option B: Via GitHub Actions

Create `.github/workflows/destroy-ecs.yml`:

```yaml
name: Destroy ECS Infrastructure

on:
  workflow_dispatch:
    inputs:
      confirm_destroy:
        description: 'Type "destroy" to confirm deletion'
        required: true
      environment:
        description: 'Environment to destroy'
        required: true
        type: choice
        options:
          - dev
          - staging

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-west-2

jobs:
  destroy:
    name: Terraform Destroy
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm_destroy == 'destroy'
    environment:
      name: ${{ github.event.inputs.environment }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.9'

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-Destroy

      - name: Get ECR repository URL
        id: ecr
        run: |
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          ECR_URL="${ACCOUNT_ID}.dkr.ecr.${{ env.AWS_REGION }}.amazonaws.com/retail-store"
          echo "repository_url=${ECR_URL}" >> $GITHUB_OUTPUT

      - name: Terraform Init
        working-directory: terraform/ecs/managed-instances
        run: terraform init

      - name: Terraform Destroy
        working-directory: terraform/ecs/managed-instances
        env:
          TF_VAR_container_image_repository: ${{ steps.ecr.outputs.repository_url }}
        run: terraform destroy -auto-approve -input=false

      - name: Summary
        run: |
          echo "### Infrastructure Destroyed 🗑️" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Environment:** ${{ github.event.inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "**Cluster:** retail-store-ecs-mi-cluster" >> $GITHUB_STEP_SUMMARY
          echo "**Status:** All resources deleted" >> $GITHUB_STEP_SUMMARY
```

Then trigger via GitHub Actions UI.

### Step 2: Destroy ECR Repositories (Phase 2)

This removes container image storage.

```bash
cd terraform/ecr

# Review what will be destroyed
terraform plan -destroy

# Destroy repositories
terraform destroy

# Type 'yes' when prompted
```

**Time**: 1-2 minutes  
**Resources Deleted**: 
- 5 ECR repositories
- 5 lifecycle policies
- All container images

**Note**: If repositories contain images, you may need to force delete:

```bash
# Delete all images first
for repo in ui catalog cart orders checkout; do
  aws ecr batch-delete-image \
    --repository-name retail-store-${repo} \
    --image-ids "$(aws ecr list-images --repository-name retail-store-${repo} --region us-west-2 --query 'imageIds[*]' --output json)" \
    --region us-west-2
done

# Then destroy
terraform destroy
```

### Step 3: Destroy Bootstrap Infrastructure (Phase 1)

**⚠️ WARNING**: Only do this if you're completely done. This removes:
- Terraform state storage
- State locking
- GitHub Actions IAM role

```bash
cd terraform/bootstrap

# First, remove prevent_destroy lifecycle blocks
# Edit main.tf and remove these lines from S3 bucket and DynamoDB table:
#   lifecycle {
#     prevent_destroy = true
#   }

# Review what will be destroyed
terraform plan -destroy

# Destroy bootstrap resources
terraform destroy

# Type 'yes' when prompted
```

**Time**: 1-2 minutes  
**Resources Deleted**:
- S3 state bucket (and all state files)
- DynamoDB locks table
- GitHub OIDC provider
- IAM role for GitHub Actions

**⚠️ After this**: You cannot run Terraform for this project anymore without re-bootstrapping.

## Partial Cleanup Options

### Option A: Pause Instead of Destroy

Save costs without losing data:

```bash
# Stop RDS clusters (saves ~$50/month)
aws rds stop-db-cluster --db-cluster-identifier retail-store-ecs-mi-catalog --region us-west-2
aws rds stop-db-cluster --db-cluster-identifier retail-store-ecs-mi-orders --region us-west-2

# Stop Amazon MQ broker (saves ~$25/month)
aws mq update-broker --broker-id <broker-id> --auto-minor-version-upgrade false --region us-west-2
# Note: MQ doesn't have stop, only delete

# Scale ECS services to 0 (saves ~$75/month)
for service in ui catalog cart orders checkout; do
  aws ecs update-service \
    --cluster retail-store-ecs-mi-cluster \
    --service $service \
    --desired-count 0 \
    --region us-west-2
done
```

**Resume later**:
```bash
# Start RDS
aws rds start-db-cluster --db-cluster-identifier retail-store-ecs-mi-catalog --region us-west-2

# Scale ECS back up
aws ecs update-service --cluster retail-store-ecs-mi-cluster --service ui --desired-count 2 --region us-west-2
```

### Option B: Keep Infrastructure, Delete Images

Keep the infrastructure but remove old images:

```bash
# ECR lifecycle policies will auto-delete old images
# Or manually delete specific tags:
aws ecr batch-delete-image \
  --repository-name retail-store-ui \
  --image-ids imageTag=old-tag \
  --region us-west-2
```

## Verification After Cleanup

### Verify ECS Destroyed
```bash
aws ecs list-clusters --region us-west-2 | grep retail-store
# Should return nothing
```

### Verify ECR Destroyed
```bash
aws ecr describe-repositories --region us-west-2 | grep retail-store
# Should return nothing
```

### Verify VPC Destroyed
```bash
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Environment,Values=retail-store-ecs-mi"
# Should return empty
```

### Check for Orphaned Resources

Sometimes resources don't delete cleanly:

```bash
# Check for lingering security groups
aws ec2 describe-security-groups --region us-west-2 --filters "Name=tag:Project,Values=retail-store"

# Check for lingering ENIs
aws ec2 describe-network-interfaces --region us-west-2 --filters "Name=tag:Project,Values=retail-store"

# Check for lingering EBS volumes
aws ec2 describe-volumes --region us-west-2 --filters "Name=tag:Project,Values=retail-store"
```

## Troubleshooting Destroy Issues

### Error: "Resource still in use"

**Common with**:
- VPC (ENIs still attached)
- Security groups (referenced by other resources)
- IAM roles (attached to running resources)

**Solution**:
```bash
# Wait 5-10 minutes for AWS to clean up dependencies
# Then retry destroy

# Or manually delete the blocking resource first
```

### Error: "DependencyViolation"

**Cause**: Resources have dependencies that must be deleted first

**Solution**:
```bash
# Terraform usually handles this, but if it fails:
# 1. Note which resource is blocking
# 2. Manually delete that resource via AWS CLI/Console
# 3. Re-run terraform destroy
```

### Error: "Cannot delete non-empty S3 bucket"

**Cause**: Terraform state bucket has objects

**Solution**:
```bash
# Empty the bucket first
aws s3 rm s3://retail-store-terraform-state-173471018689 --recursive --region us-west-2

# Then destroy
terraform destroy
```

## Cost After Each Step

| After Destroying | Monthly Cost |
|------------------|--------------|
| ECS Infrastructure | ~$5 (ECR + Bootstrap) |
| ECR Repositories | ~$5 (Bootstrap only) |
| Bootstrap | $0 |

## Cleanup Checklist

- [ ] Backup any important data from RDS/DynamoDB
- [ ] Export CloudWatch logs if needed for analysis
- [ ] Document any findings from agent evaluation
- [ ] Destroy ECS infrastructure (Phase 3)
- [ ] Destroy ECR repositories (Phase 2)
- [ ] Destroy bootstrap infrastructure (Phase 1) - optional
- [ ] Verify no orphaned resources remain
- [ ] Remove GitHub secrets (AWS_ROLE_ARN) - optional
- [ ] Delete GitHub Actions workflow runs history - optional

## Emergency Cleanup

If Terraform is broken and you need to force cleanup:

```bash
# List all resources with Project tag
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=retail-store \
  --region us-west-2

# Manually delete each resource type
# Start with: ECS services, tasks, cluster
# Then: RDS, DynamoDB, ElastiCache, MQ
# Then: ALB, target groups
# Then: VPC components
# Finally: IAM roles, security groups
```

## Preventing Accidental Deletion

### Add Lifecycle Protection

In `main.tf`:
```hcl
resource "aws_rds_cluster" "..." {
  # ...
  deletion_protection = true
}

resource "aws_dynamodb_table" "..." {
  # ...
  deletion_protection_enabled = true
}
```

### Use Terraform Workspaces

```bash
# Create separate workspace for prod
terraform workspace new prod

# Prod requires explicit workspace selection
terraform workspace select prod
terraform destroy  # Only affects prod workspace
```

### Require Manual Approval

In destroy workflow, add:
```yaml
environment:
  name: production
  # Requires manual approval in GitHub
```

## Recovery After Accidental Deletion

If you accidentally destroy and have Terraform state:

```bash
# State is in S3, you can redeploy
cd terraform/ecs/managed-instances
terraform init
terraform apply

# Infrastructure will be recreated
# Data in databases will be lost unless you had backups
```

## Data Backup Before Destroy

### Backup RDS
```bash
# Create snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier retail-store-ecs-mi-catalog \
  --db-cluster-snapshot-identifier retail-store-catalog-final-snapshot \
  --region us-west-2
```

### Export DynamoDB
```bash
# Export to S3
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:us-west-2:173471018689:table/retail-store-ecs-mi-carts \
  --s3-bucket my-backup-bucket \
  --region us-west-2
```

### Export CloudWatch Logs
```bash
# Export logs to S3
aws logs create-export-task \
  --log-group-name retail-store-ecs-mi-tasks \
  --from $(date -d '30 days ago' +%s)000 \
  --to $(date +%s)000 \
  --destination my-backup-bucket \
  --destination-prefix ecs-logs \
  --region us-west-2
```

## Summary

**Quick Cleanup** (no data backup):
```bash
cd terraform/ecs/managed-instances && terraform destroy
cd ../../../terraform/ecr && terraform destroy
```

**Safe Cleanup** (with backups):
1. Export CloudWatch logs
2. Snapshot RDS clusters
3. Export DynamoDB table
4. Run terraform destroy
5. Verify all resources deleted
6. Keep bootstrap for future use

**Complete Cleanup** (remove everything):
1. Destroy ECS
2. Destroy ECR
3. Edit bootstrap main.tf (remove prevent_destroy)
4. Destroy bootstrap
5. Remove GitHub secret (AWS_ROLE_ARN)
