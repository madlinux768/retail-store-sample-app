# VPC Endpoints for ECR access from private subnets
# Required for ECS tasks to pull images from ECR without going through NAT Gateway

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.environment_name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = module.vpc.inner.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.inner.vpc_cidr_block]
    description = "Allow HTTPS from VPC"
  }

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
      Name = "${var.environment_name}-vpc-endpoints"
    }
  )
}

# ECR API endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.inner.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.inner.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-ecr-api"
    }
  )
}

# ECR Docker endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.inner.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.inner.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-ecr-dkr"
    }
  )
}

# S3 Gateway endpoint (for ECR image layers)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.inner.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.inner.private_route_table_ids

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-s3"
    }
  )
}

# CloudWatch Logs endpoint (for container logs)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.inner.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.inner.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-logs"
    }
  )
}
