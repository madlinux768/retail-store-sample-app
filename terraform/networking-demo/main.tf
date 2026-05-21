# Networking Demo Infrastructure
#
# Deploys a "partner network" VPC connected via Transit Gateway to the app VPC,
# with monitoring to detect connectivity failures.
#
# This module uses two providers:
# - "aws" (default) = networking account (owns VPC2, TGW, partner EC2)
# - "aws.app" = app account (TGW attachment, NLB, Route53 PHZ, synthetic Lambda)

provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.networking_role_arn
  }

  default_tags {
    tags = {
      Project     = "retail-store"
      ManagedBy   = "Terraform"
      auto-delete = "no"
      Purpose     = "networking-demo"
    }
  }
}

provider "aws" {
  alias  = "app"
  region = var.region

  default_tags {
    tags = {
      Project     = "retail-store"
      ManagedBy   = "Terraform"
      auto-delete = "no"
      Purpose     = "networking-demo"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "networking" {}
