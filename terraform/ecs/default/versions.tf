terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "retail-store-terraform-state-173471018689"
    key            = "retail-store/ecs/default/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "retail-store-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Environment = "retail-store-ecs"
      Project     = "retail-store"
      ManagedBy   = "Terraform"
      auto-delete = "no"
    }
  }
}
