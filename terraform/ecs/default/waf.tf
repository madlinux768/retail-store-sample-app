# WAF IP Allowlist for ALB
# Restricts access to the application to authorized IP addresses

# IP Set with allowed IPs
resource "aws_wafv2_ip_set" "allowed_ips" {
  name               = "${var.environment_name}-allowed-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  
  addresses = [
    "47.149.71.130/32",  # Your IP
    # Add additional IPs here as needed
    # "10.0.0.0/8",      # Corporate network
    # "192.168.1.0/24",  # VPN range
  ]

  tags = {
    Name                = "${var.environment_name}-allowed-ips"
    created-by          = "retail-store-sample-app"
    environment-name    = var.environment_name
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "alb" {
  name  = "${var.environment_name}-alb-acl"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  # Allow traffic from allowed IPs
  rule {
    name     = "AllowListedIPs"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowed_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment_name}-allowed-ips"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name                = "${var.environment_name}-alb-acl"
    created-by          = "retail-store-sample-app"
    environment-name    = var.environment_name
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = module.retail_app_ecs.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
