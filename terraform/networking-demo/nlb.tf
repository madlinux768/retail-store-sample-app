# Network Load Balancer in the app VPC that routes to partner service via TGW

resource "aws_lb" "partner" {
  provider = aws.app

  name               = "partner-service-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.app_private_subnet_ids

  access_logs {
    bucket  = aws_s3_bucket.nlb_logs.bucket
    enabled = true
  }

  tags = { Name = "partner-service-nlb" }
}

resource "aws_lb_target_group" "partner" {
  provider = aws.app

  name        = "partner-service-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.app_vpc_id

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "partner-service-tg" }
}

resource "aws_lb_target_group_attachment" "partner" {
  provider = aws.app

  target_group_arn  = aws_lb_target_group.partner.arn
  target_id         = aws_instance.partner.private_ip
  port              = 80
  availability_zone = "all"
}

resource "aws_lb_listener" "partner" {
  provider = aws.app

  load_balancer_arn = aws_lb.partner.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.partner.arn
  }
}
