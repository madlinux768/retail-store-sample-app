terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket         = "retail-store-terraform-state-173471018689"
    key            = "retail-store/networking-demo/terraform.tfstate"
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
