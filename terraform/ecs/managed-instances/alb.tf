module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name = "${var.environment_name}-alb"

  load_balancer_type = "application"

  vpc_id  = module.vpc.inner.vpc_id
  subnets = module.vpc.inner.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow HTTP from internet"
    }
  }

  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = module.vpc.inner.vpc_cidr_block
      description = "Allow all to VPC"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "ui"
      }
    }
  }

  target_groups = {
    ui = {
      backend_protocol                  = "HTTP"
      backend_port                      = 8080
      target_type                       = "ip"
      deregistration_delay              = 30
      load_balancing_cross_zone_enabled = true

      health_check = {
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

      create_attachment = false
    }
  }

  tags = module.tags.result
}
