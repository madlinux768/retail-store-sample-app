terraform {
  required_version = ">= 1.0"

  # Backend configuration - update with your values from bootstrap
  # backend "s3" {
  #   bucket         = "retail-store-terraform-state-ACCOUNT_ID"
  #   key            = "ecs/managed-instances/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "retail-store-terraform-locks"
  #   encrypt        = true
  # }
}
