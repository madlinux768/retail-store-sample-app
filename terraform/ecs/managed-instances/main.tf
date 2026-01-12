terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment_name
      Project     = "retail-store"
      ManagedBy   = "Terraform"
      auto-delete = "yes"
    }
  }
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  
  container_images = {
    ui       = "${var.container_image_repository}-ui:${var.container_image_tag}"
    catalog  = "${var.container_image_repository}-catalog:${var.container_image_tag}"
    cart     = "${var.container_image_repository}-cart:${var.container_image_tag}"
    orders   = "${var.container_image_repository}-orders:${var.container_image_tag}"
    checkout = "${var.container_image_repository}-checkout:${var.container_image_tag}"
  }
}

module "tags" {
  source = "../../lib/tags"

  environment_name = var.environment_name
}

module "vpc" {
  source = "../../lib/vpc"

  environment_name = var.environment_name
  tags             = module.tags.result
}

# Security Group for Database Access
resource "aws_security_group" "database_clients" {
  name        = "${var.environment_name}-database-clients"
  description = "Security group for services accessing databases"
  vpc_id      = module.vpc.inner.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-database-clients"
    }
  )
}

module "dependencies" {
  source = "../../lib/dependencies"

  environment_name = var.environment_name
  tags             = module.tags.result

  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets

  catalog_security_group_id  = aws_security_group.database_clients.id
  orders_security_group_id   = aws_security_group.database_clients.id
  checkout_security_group_id = aws_security_group.database_clients.id
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "${var.environment_name}-tasks"
  retention_in_days = 30

  tags = module.tags.result
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "retailstore.local"
  description = "Service discovery namespace"
  vpc         = module.vpc.inner.vpc_id

  tags = module.tags.result
}

# IAM Role for ECS Infrastructure
resource "aws_iam_role" "ecs_infrastructure" {
  name = "${var.environment_name}-ecs-infrastructure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = module.tags.result
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  role       = aws_iam_role.ecs_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForManagedInstances"
}

# IAM Instance Profile
resource "aws_iam_role" "ecs_instance" {
  name = "${var.environment_name}-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = module.tags.result
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ecr" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_cloudwatch" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.environment_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name

  tags = module.tags.result
}

# ECS Cluster with Managed Instances
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 7.1"

  name = "${var.environment_name}-cluster"

  setting = [{
    name  = "containerInsights"
    value = var.container_insights_setting
  }]

  capacity_providers = {
    managed-instances = {
      managed_instances_provider = {
        instance_launch_template = {
          ec2_instance_profile_arn = aws_iam_instance_profile.ecs.arn

          instance_requirements = {
            instance_generations = ["current"]

            memory_mib = {
              min = 2048
              max = 8192
            }

            vcpu_count = {
              min = 1
              max = 4
            }
          }

          network_configuration = {
            subnets = module.vpc.inner.private_subnets
          }

          storage_configuration = {
            storage_size_gib = 30
          }
        }

        infrastructure_role_arn = aws_iam_role.ecs_infrastructure.arn
      }
    }
  }

  vpc_id = module.vpc.inner.vpc_id
  security_group_ingress_rules = {
    all_traffic = {
      from_port   = 0
      to_port     = 65535
      ip_protocol = "tcp"
      cidr_ipv4   = module.vpc.inner.vpc_cidr_block
      description = "Allow all TCP traffic within VPC"
    }
  }
  security_group_egress_rules = {
    all = {
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
      description = "Allow all outbound"
    }
  }

  tags = module.tags.result
}
