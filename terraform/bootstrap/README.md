# Bootstrap Infrastructure

This Terraform configuration sets up the foundational AWS infrastructure needed for deploying the retail store application via GitHub Actions.

## What This Creates

1. **S3 Bucket** - Stores Terraform state files with versioning and encryption
2. **DynamoDB Table** - Provides state locking to prevent concurrent modifications
3. **GitHub OIDC Provider** - Enables secure authentication from GitHub Actions without long-lived credentials
4. **IAM Role** - Grants GitHub Actions the permissions needed to deploy infrastructure

## Prerequisites

- AWS CLI installed and configured with admin credentials
- Terraform >= 1.0 installed
- Your GitHub organization/username and repository name

## Setup Instructions

### Step 1: Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region  = "us-east-1"
project_name = "retail-store"
github_org  = "YOUR_GITHUB_ORG_OR_USERNAME"
github_repo = "retail-store-sample-app"
```

Replace `YOUR_GITHUB_ORG_OR_USERNAME` with your actual GitHub organization or username.

### Step 2: Initialize and Apply

```bash
cd terraform/bootstrap

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

Type `yes` when prompted to create the resources.

### Step 3: Save Outputs

After successful apply, save the outputs:

```bash
# Get the GitHub Actions role ARN
terraform output -raw github_actions_role_arn

# Get the S3 bucket name
terraform output -raw terraform_state_bucket

# Get the DynamoDB table name
terraform output -raw terraform_locks_table
```

### Step 4: Configure GitHub Secrets

Add the following secret to your GitHub repository:

1. Go to your repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add:
   - Name: `AWS_ROLE_ARN`
   - Value: (paste the role ARN from terraform output)

### Step 5: Update Deployment Terraform Modules

For each deployment module (EKS, ECS, App Runner), add a backend configuration.

Create a file named `backend.tf` in the deployment directory (e.g., `terraform/eks/default/backend.tf`):

```hcl
terraform {
  backend "s3" {
    bucket         = "retail-store-terraform-state-YOUR_ACCOUNT_ID"
    key            = "eks/default/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }
}
```

Replace:
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `eks/default` with the appropriate path for each module

## Security Notes

- The S3 bucket has versioning enabled to protect against accidental deletions
- Public access is completely blocked on the state bucket
- State files are encrypted at rest
- The IAM role uses OIDC for secure, temporary credentials
- State locking prevents concurrent modifications

## Cost Estimate

- S3 bucket: ~$0.023/GB/month (minimal for state files)
- DynamoDB table: Pay-per-request (typically < $1/month)
- Total: < $5/month for bootstrap infrastructure

## Cleanup

**WARNING**: Only run this if you want to completely remove all infrastructure.

```bash
# Remove the prevent_destroy lifecycle first
# Edit main.tf and remove the lifecycle blocks, then:

terraform destroy
```

## Troubleshooting

### Error: "EntityAlreadyExists: Provider with url https://token.actions.githubusercontent.com already exists"

The OIDC provider already exists. You can either:
1. Import it: `terraform import aws_iam_openid_connect_provider.github arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com`
2. Or remove the resource from this configuration and manage it separately

### Error: "Access Denied" when applying

Ensure your AWS credentials have administrator access or at minimum:
- IAM full access
- S3 full access
- DynamoDB full access

## Next Steps

After completing bootstrap:
1. Configure your deployment module backend (see Step 5)
2. Create GitHub Actions workflow for deployment
3. Deploy your chosen platform (EKS/ECS/App Runner)
