# Logging resources for the networking demo
#
# Networking account (default provider, 378147474529):
#   - VPC flow logs for the partner VPC
#   - TGW flow logs
#   - Supporting CloudWatch log groups and IAM role
#
# App account (aws.app provider, 173471018689):
#   - Lambda function log group
#   - Route53 Resolver query log group, config, and association
#   - S3 bucket for NLB access logs

# ---------------------------------------------------------------------------
# Networking account — CloudWatch Log Groups
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/networking-demo-partner"
  retention_in_days = 7

  tags = { Name = "networking-demo-partner-vpc-flow-logs" }
}

resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  name              = "/aws/tgw/networking-demo"
  retention_in_days = 7

  tags = { Name = "networking-demo-tgw-flow-logs" }
}

# ---------------------------------------------------------------------------
# Networking account — IAM Role for VPC / TGW Flow Logs
# ---------------------------------------------------------------------------

resource "aws_iam_role" "flow_logs" {
  name = "networking-demo-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "networking-demo-flow-logs" }
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}

# ---------------------------------------------------------------------------
# Networking account — VPC Flow Log (partner VPC)
# ---------------------------------------------------------------------------

resource "aws_flow_log" "partner_vpc" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.partner.id
  max_aggregation_interval = 60

  tags = { Name = "networking-demo-partner-vpc-flow-log" }
}

# ---------------------------------------------------------------------------
# Networking account — TGW Flow Log
# TransitGateway resource type does not support traffic_type.
# ---------------------------------------------------------------------------

resource "aws_flow_log" "tgw" {
  iam_role_arn             = aws_iam_role.flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.tgw_flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  transit_gateway_id       = aws_ec2_transit_gateway.demo.id
  max_aggregation_interval = 60

  tags = { Name = "networking-demo-tgw-flow-log" }
}

# ---------------------------------------------------------------------------
# App account — CloudWatch Log Groups
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda_connectivity_check" {
  provider = aws.app

  name              = "/aws/lambda/networking-demo-connectivity-check"
  retention_in_days = 7

  tags = { Name = "networking-demo-connectivity-check-logs" }
}

resource "aws_cloudwatch_log_group" "route53_resolver" {
  provider = aws.app

  name              = "/aws/route53resolver/networking-demo"
  retention_in_days = 7

  tags = { Name = "networking-demo-route53-resolver-logs" }
}

# ---------------------------------------------------------------------------
# App account — S3 Bucket for NLB Access Logs
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "nlb_logs" {
  provider = aws.app

  bucket = "networking-demo-nlb-logs-${var.app_account_id}"

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "networking-demo-nlb-logs" }
}

resource "aws_s3_bucket_policy" "nlb_logs" {
  provider = aws.app

  bucket = aws_s3_bucket.nlb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowNLBLogDeliveryPut"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.nlb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"    = "bucket-owner-full-control"
            "aws:SourceAccount" = var.app_account_id
          }
        }
      },
      {
        Sid    = "AllowNLBLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.nlb_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.app_account_id
          }
        }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# App account — Route53 Resolver Query Logging
# ---------------------------------------------------------------------------

resource "aws_route53_resolver_query_log_config" "networking_demo" {
  provider = aws.app

  name            = "networking-demo-query-log"
  destination_arn = aws_cloudwatch_log_group.route53_resolver.arn

  tags = { Name = "networking-demo-query-log" }
}

resource "aws_route53_resolver_query_log_config_association" "app_vpc" {
  provider = aws.app

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.networking_demo.id
  resource_id                  = var.app_vpc_id
}
