terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

module "tags" {
  source = "../../lib/tags"

  environment_name = var.environment_name
}

module "vpc" {
  source = "../../lib/vpc"

  environment_name = var.environment_name
  tags             = module.tags.result
}

module "dependencies" {
  source = "../../lib/dependencies"

  environment_name = var.environment_name
  tags             = module.tags.result

  vpc_id     = module.vpc.inner.vpc_id
  subnet_ids = module.vpc.inner.private_subnets

  catalog_security_group_id  = aws_security_group.catalog.id
  orders_security_group_id   = aws_security_group.orders.id
  checkout_security_group_id = aws_security_group.checkout.id
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${var.environment_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.container_insights_setting
  }

  tags = module.tags.result
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

# IAM Role for ECS Managed Instances Infrastructure
resource "aws_iam_role" "ecs_infrastructure" {
  name = "${var.environment_name}-ecs-infrastructure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = module.tags.result
}

resource "aws_iam_role_policy_attachment" "ecs_infrastructure" {
  role       = aws_iam_role.ecs_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForManagedInstances"
}

# IAM Instance Profile for ECS Managed Instances
resource "aws_iam_role" "ecs_instance" {
  name = "${var.environment_name}-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
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

# ECS Managed Instances Capacity Provider
resource "aws_ecs_capacity_provider" "managed_instances" {
  name = "${var.environment_name}-managed-instances"

  managed_instance_scaling {
    instance_warmup_period    = 60
    minimum_scaling_step_size = 1
    maximum_scaling_step_size = 10
    status                    = "ENABLED"
    target_capacity           = 80
  }

  managed_instance_requirements {
    instance_profile = aws_iam_instance_profile.ecs.arn
    instance_types   = var.instance_types

    network_configuration {
      security_group_ids = [aws_security_group.ecs_instances.id]
      subnet_ids         = module.vpc.inner.private_subnets
    }
  }

  managed_infrastructure {
    infrastructure_role_arn = aws_iam_role.ecs_infrastructure.arn
  }

  tags = module.tags.result
}

# Attach capacity provider to cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [aws_ecs_capacity_provider.managed_instances.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.managed_instances.name
    weight            = 1
    base              = 1
  }
}

# Security Group for ECS Instances
resource "aws_security_group" "ecs_instances" {
  name        = "${var.environment_name}-ecs-instances"
  description = "Security group for ECS Managed Instances"
  vpc_id      = module.vpc.inner.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-ecs-instances"
    }
  )
}

# Security Groups for Services
resource "aws_security_group" "catalog" {
  name        = "${var.environment_name}-catalog"
  description = "Security group for catalog service"
  vpc_id      = module.vpc.inner.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
    description     = "Allow traffic from ECS instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-catalog"
    }
  )
}

resource "aws_security_group" "orders" {
  name        = "${var.environment_name}-orders"
  description = "Security group for orders service"
  vpc_id      = module.vpc.inner.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
    description     = "Allow traffic from ECS instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-orders"
    }
  )
}

resource "aws_security_group" "checkout" {
  name        = "${var.environment_name}-checkout"
  description = "Security group for checkout service"
  vpc_id      = module.vpc.inner.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
    description     = "Allow traffic from ECS instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-checkout"
    }
  )
}

data "aws_caller_identity" "current" {}
