# Deployment Setup Guide

Complete guide for deploying the AWS Containers Retail Sample to your AWS account via GitHub Actions.

## Overview

This guide walks through setting up automated deployments using:
- **Terraform** for infrastructure as code
- **GitHub Actions** for CI/CD
- **AWS OIDC** for secure authentication (no long-lived credentials)
- **Remote state** for team collaboration

## Phase 1: Bootstrap Infrastructure (One-Time Setup)

### Prerequisites

- AWS account with admin access
- AWS CLI configured locally
- Terraform >= 1.0 installed
- GitHub repository (fork or your own)

### Step-by-Step Setup

#### 1. Clone and Navigate

```bash
git clone https://github.com/YOUR_ORG/retail-store-sample-app.git
cd retail-store-sample-app/terraform/bootstrap
```

#### 2. Configure Variables

Create `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "retail-store"
github_org   = "your-github-username"  # or organization name
github_repo  = "retail-store-sample-app"
```

#### 3. Deploy Bootstrap Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Review the plan carefully, then type `yes` to proceed.

#### 4. Save Important Outputs

```bash
# Save these values - you'll need them
terraform output github_actions_role_arn
terraform output terraform_state_bucket
terraform output terraform_locks_table
terraform output aws_account_id
```

#### 5. Configure GitHub Repository

Add the GitHub secret:

1. Go to: `https://github.com/YOUR_ORG/retail-store-sample-app/settings/secrets/actions`
2. Click "New repository secret"
3. Add:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: (paste the role ARN from step 4)

#### 6. Update Deployment Modules

Choose your deployment platform and update its backend configuration.

**For EKS:**

Create `terraform/eks/default/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "retail-store-terraform-state-123456789012"  # Use your bucket name
    key            = "eks/default/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }
}
```

**For ECS:**

Create `terraform/ecs/default/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "retail-store-terraform-state-123456789012"  # Use your bucket name
    key            = "ecs/default/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }
}
```

**For App Runner:**

Create `terraform/apprunner/default/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "retail-store-terraform-state-123456789012"  # Use your bucket name
    key            = "apprunner/default/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }
}
```

## Verification

Test that GitHub Actions can authenticate:

```bash
# In your repository, create a test workflow or use the AWS CLI locally
aws sts get-caller-identity --profile your-profile
```

## What Was Created

| Resource | Purpose | Cost |
|----------|---------|------|
| S3 Bucket | Terraform state storage | ~$0.02/month |
| DynamoDB Table | State locking | ~$0.50/month |
| OIDC Provider | GitHub authentication | Free |
| IAM Role | GitHub Actions permissions | Free |

**Total Bootstrap Cost**: < $5/month

## Security Features

✅ No long-lived AWS credentials in GitHub
✅ Encrypted state files at rest
✅ State file versioning enabled
✅ Public access blocked on S3 bucket
✅ State locking prevents conflicts
✅ Least privilege IAM permissions

## Next Steps

Phase 1 is complete! You can now:

1. **Phase 2**: Create deployment workflows for GitHub Actions
2. **Phase 3**: Deploy your chosen platform (EKS/ECS/App Runner)

Choose your deployment platform:
- [EKS Deployment](../terraform/eks/default/README.md) - Full Kubernetes features
- [ECS Deployment](../terraform/ecs/default/README.md) - Managed containers
- [App Runner Deployment](../terraform/apprunner/default/README.md) - Simplest option

## Troubleshooting

### "EntityAlreadyExists" Error

The OIDC provider already exists in your account. Import it:

```bash
terraform import aws_iam_openid_connect_provider.github \
  arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### "Access Denied" Errors

Ensure your AWS credentials have sufficient permissions:
- IAM: CreateRole, CreatePolicy, CreateOpenIDConnectProvider
- S3: CreateBucket, PutBucketPolicy
- DynamoDB: CreateTable

### State Bucket Already Exists

If you're re-running bootstrap, import the existing bucket:

```bash
terraform import aws_s3_bucket.terraform_state retail-store-terraform-state-YOUR_ACCOUNT_ID
```

## Cleanup

To remove bootstrap infrastructure (⚠️ **WARNING**: This will delete state storage):

```bash
cd terraform/bootstrap

# First, remove prevent_destroy from main.tf lifecycle blocks
# Then:
terraform destroy
```

## Support

For issues or questions:
- Check [GitHub Issues](https://github.com/aws-containers/retail-store-sample-app/issues)
- Review [AWS Documentation](https://docs.aws.amazon.com/)
- See [Terraform Documentation](https://www.terraform.io/docs)
