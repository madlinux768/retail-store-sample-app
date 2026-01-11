output "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_locks_table" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (add this to GitHub secrets as AWS_ROLE_ARN)"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "backend_config" {
  description = "Backend configuration for other Terraform modules"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    key            = "REPLACE_WITH_PATH/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.terraform_locks.id
    encrypt        = true
  }
}
