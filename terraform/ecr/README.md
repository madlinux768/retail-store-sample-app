# ECR Repositories

This Terraform module creates private Amazon ECR repositories for all microservices in the retail store application.

## What This Creates

- **5 ECR Repositories** - One for each microservice (ui, catalog, cart, orders, checkout)
- **Image Scanning** - Automatic vulnerability scanning on push
- **Lifecycle Policies** - Automatic cleanup of old images
- **Encryption** - AES256 encryption at rest

## Repository Naming

Repositories follow the pattern: `{project_name}-{service}`

Example: `retail-store-ui`, `retail-store-catalog`

## Lifecycle Policy

- **Tagged images**: Keep last 10 images with `v` prefix
- **Untagged images**: Remove after 7 days

## Usage

### Deploy ECR Repositories

```bash
cd terraform/ecr

terraform init
terraform plan
terraform apply
```

### Get Repository URLs

```bash
terraform output repository_urls
```

### Push an Image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw registry_id).dkr.ecr.us-east-1.amazonaws.com

# Tag your image
docker tag retail-store-ui:latest \
  $(terraform output -json repository_urls | jq -r '.ui'):latest

# Push to ECR
docker push $(terraform output -json repository_urls | jq -r '.ui'):latest
```

## Security Features

- ✅ Encryption at rest (AES256)
- ✅ Automatic vulnerability scanning
- ✅ Lifecycle policies for image cleanup
- ✅ Private repositories (not publicly accessible)
- ✅ IAM-based access control

## Cost Optimization

- Lifecycle policies automatically remove old images
- Only pay for storage of images you're using
- Typical cost: ~$0.10/GB/month for storage

## Integration with GitHub Actions

The GitHub Actions workflow will:
1. Authenticate to ECR using OIDC
2. Build multi-arch images
3. Tag with commit SHA and version
4. Push to appropriate repository
5. Trigger vulnerability scan

## Cleanup

To remove all repositories:

```bash
# WARNING: This will delete all images
terraform destroy
```

Note: You may need to delete images first if repositories are not empty.
