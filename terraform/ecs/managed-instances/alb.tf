# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${var.environment_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.inner.public_subnets

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-alb"
    }
  )
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.environment_name}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.inner.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
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
      Name = "${var.environment_name}-alb"
    }
  )
}

# Allow ALB to reach ECS instances
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_instances.id
  description              = "Allow ALB to reach ECS tasks"
}

# Target Group for UI
resource "aws_lb_target_group" "ui" {
  name        = "${var.environment_name}-ui"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.inner.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(
    module.tags.result,
    {
      Name = "${var.environment_name}-ui"
    }
  )
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  tags = module.tags.result
}
