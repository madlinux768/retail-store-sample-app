locals {
  environment = concat(
    [for k, v in var.environment_variables : {
      name  = k
      value = v
    }],
    var.opentelemetry_enabled ? [
      {
        name  = "OTEL_SDK_DISABLED"
        value = "false"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
        value = "http/protobuf"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://localhost:4318"
      },
      {
        name  = "OTEL_SERVICE_NAME"
        value = var.service_name
      }
    ] : []
  )

  secrets = [for k, v in var.secrets : {
    name      = k
    valueFrom = v
  }]

  container_definition = {
    name  = "${var.service_name}-service"
    image = var.container_image
    portMappings = [
      {
        containerPort = 8080
        protocol      = "tcp"
        name          = "${var.service_name}-service"
      }
    ]
    essential   = true
    environment = local.environment
    secrets     = local.secrets
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8080${var.healthcheck_path} || exit 1"]
      interval    = 10
      startPeriod = 60
      retries     = 3
      timeout     = 5
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_logs_group_id
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.service_name
      }
    }
  }
}

data "aws_region" "current" {}

# Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment_name}-${var.service_name}"
  container_definitions    = jsonencode([local.container_definition])
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  tags = var.tags
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = var.service_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
    base              = 1
  }

  network_configuration {
    security_groups = [aws_security_group.service.id]
    subnets         = var.subnet_ids
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_discovery_namespace_arn
    service {
      client_alias {
        dns_name = var.service_name
        port     = 80
      }
      discovery_name = var.service_name
      port_name      = "${var.service_name}-service"
    }
  }

  dynamic "load_balancer" {
    for_each = var.alb_target_group_arn != "" ? [1] : []

    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = "${var.service_name}-service"
      container_port   = 8080
    }
  }

  enable_execute_command = true

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.task_execution_ecs]
}

# Security Group for Service
resource "aws_security_group" "service" {
  name        = "${var.environment_name}-${var.service_name}"
  description = "Security group for ${var.service_name} service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.ecs_instance_security_group_id]
    description     = "Allow traffic from ECS instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment_name}-${var.service_name}"
    }
  )
}
