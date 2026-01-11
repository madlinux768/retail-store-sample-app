# Phase 2: Container Image Pipeline

## Overview

This phase sets up automated building and pushing of custom container images to Amazon ECR private repositories.

## What Was Created

### 1. ECR Repositories (`terraform/ecr/`)
- **5 private repositories** - One per microservice
- **Automatic scanning** - Vulnerability detection on push
- **Lifecycle policies** - Cleanup of old images
- **Encryption** - AES256 at rest

### 2. GitHub Actions Workflow (`.github/workflows/build-push-images.yml`)
- **Smart change detection** - Only builds changed services
- **Multi-arch builds** - Supports x86_64 and ARM64
- **Automatic tagging** - Commit SHA, timestamp, latest
- **Vulnerability scanning** - ECR image scanning
- **PR support** - Builds images for PRs without pushing

### 3. Updated IAM Permissions
- ECR repository management
- Image push/pull operations
- Vulnerability scanning access

## Setup Instructions

### Step 1: Deploy ECR Repositories

```bash
cd terraform/ecr

# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create the repositories
terraform apply
```

This creates 5 ECR repositories:
- `retail-store-ui`
- `retail-store-catalog`
- `retail-store-cart`
- `retail-store-orders`
- `retail-store-checkout`

### Step 2: Verify Repositories

```bash
# Get repository URLs
terraform output repository_urls

# List repositories via AWS CLI
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[?starts_with(repositoryName, `retail-store`)].repositoryName'
```

### Step 3: Test the Workflow

The workflow triggers automatically on:
- **Push to main** - When service code changes
- **Pull requests** - Builds but doesn't push
- **Manual dispatch** - Build specific services or all

#### Manual Trigger

1. Go to GitHub Actions tab
2. Select "Build and Push Container Images"
3. Click "Run workflow"
4. Choose services to build (or "all")

#### Automatic Trigger

Make a change to any service:

```bash
# Example: Update catalog service
echo "# Test change" >> src/catalog/README.md
git add src/catalog/README.md
git commit -m "test: trigger catalog build"
git push
```

## How It Works

### Change Detection

The workflow intelligently detects which services changed:

```yaml
# Checks git diff for changes in src/{service}/ directories
# Only builds services that have code changes
```

### Build Process

For each changed service:

1. **Checkout code**
2. **Set up Docker Buildx** (multi-arch support)
3. **Authenticate to AWS** (using OIDC)
4. **Login to ECR**
5. **Build multi-arch image** (amd64 + arm64)
6. **Push to ECR** (only on main branch)
7. **Scan for vulnerabilities**
8. **Report findings**

### Image Tagging Strategy

Images are tagged with:
- **Commit SHA**: `abc1234` (7 characters)
- **Timestamp**: `20260111-143022`
- **Latest**: `latest` (only on main)
- **PR**: `pr-123` (for pull requests)

Example:
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:abc1234
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:20260111-143022
123456789012.dkr.ecr.us-east-1.amazonaws.com/retail-store-ui:latest
```

## Vulnerability Scanning

ECR automatically scans images on push. The workflow:
- Waits for scan completion
- Reports findings in workflow logs
- Warns on CRITICAL or HIGH vulnerabilities
- Does NOT block deployment (informational only)

View scan results:

```bash
aws ecr describe-image-scan-findings \
  --repository-name retail-store-ui \
  --image-id imageTag=latest \
  --region us-east-1
```

## Lifecycle Policies

Automatic cleanup keeps costs low:

**Tagged images** (with `v` prefix):
- Keep last 10 versions
- Older versions automatically deleted

**Untagged images**:
- Removed after 7 days
- Prevents accumulation of build artifacts

## Cost Optimization

- **Storage**: ~$0.10/GB/month
- **Data transfer**: Free within same region
- **Scanning**: First scan per day is free

Typical monthly cost: **$5-15** for all 5 repositories

## Troubleshooting

### Build Fails: "No such file or directory"

Check that Dockerfile exists in service directory:
```bash
ls -la src/ui/Dockerfile
```

### Authentication Fails

Verify GitHub secret is set:
1. Go to repository Settings → Secrets → Actions
2. Confirm `AWS_ROLE_ARN` exists
3. Value should match bootstrap Terraform output

### Image Push Fails: "Repository does not exist"

Deploy ECR repositories first:
```bash
cd terraform/ecr
terraform apply
```

### Scan Timeout

ECR scans can take 5-10 minutes. The workflow waits but may timeout. This is informational only and doesn't affect the build.

## Next Steps

After Phase 2 is complete:
- ✅ ECR repositories created
- ✅ Images building automatically
- ✅ Vulnerability scanning active

**Ready for Phase 3**: Deploy to ECS Managed Instances

## Monitoring

### View Recent Builds

GitHub Actions tab shows:
- Build status per service
- Build duration
- Scan findings
- Image tags created

### View Images in ECR

```bash
# List images for a service
aws ecr list-images \
  --repository-name retail-store-ui \
  --region us-east-1

# Get image details
aws ecr describe-images \
  --repository-name retail-store-ui \
  --region us-east-1
```

## Security Best Practices

✅ **Private repositories** - Not publicly accessible
✅ **Encryption at rest** - AES256
✅ **Automatic scanning** - Vulnerability detection
✅ **OIDC authentication** - No long-lived credentials
✅ **Lifecycle policies** - Automatic cleanup
✅ **Multi-arch builds** - Security updates for both architectures

## References

- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
