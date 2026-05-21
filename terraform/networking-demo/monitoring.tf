# Synthetic connectivity check Lambda + CloudWatch alarms
# Lambda runs every 60s, pings the partner service, emits custom metrics

resource "aws_iam_role" "synthetic_lambda" {
  provider = aws.app
  name     = "networking-demo-synthetic-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  provider   = aws.app
  role       = aws_iam_role.synthetic_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_cloudwatch" {
  provider = aws.app
  name     = "cloudwatch-put-metrics"
  role     = aws_iam_role.synthetic_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:PutMetricData"]
      Resource = "*"
    }]
  })
}

resource "aws_security_group" "synthetic_lambda" {
  provider = aws.app
  name     = "networking-demo-synthetic-lambda"
  vpc_id   = var.app_vpc_id

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "synthetic-lambda-sg" }
}

resource "aws_lambda_function" "connectivity_check" {
  provider = aws.app

  function_name = "networking-demo-connectivity-check"
  role          = aws_iam_role.synthetic_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  vpc_config {
    subnet_ids         = var.app_private_subnet_ids
    security_group_ids = [aws_security_group.synthetic_lambda.id]
  }

  environment {
    variables = {
      PARTNER_ENDPOINT = "http://${aws_instance.partner.private_ip}/health"
      PARTNER_DNS      = "http://api.partner.internal/health"
    }
  }

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content = <<-PYTHON
import urllib.request
import boto3
import os
import time

cloudwatch = boto3.client('cloudwatch')

def handler(event, context):
    results = {}

    # Test direct IP connectivity (TGW path)
    try:
        req = urllib.request.Request(os.environ['PARTNER_ENDPOINT'], method='GET')
        resp = urllib.request.urlopen(req, timeout=5)
        results['ip_connectivity'] = 1
        results['ip_latency_ms'] = 0  # placeholder, measured below
    except Exception as e:
        results['ip_connectivity'] = 0
        results['ip_latency_ms'] = -1
        print(f"IP connectivity failed: {e}")

    # Test DNS resolution + connectivity
    try:
        start = time.time()
        req = urllib.request.Request(os.environ['PARTNER_DNS'], method='GET')
        resp = urllib.request.urlopen(req, timeout=5)
        results['dns_connectivity'] = 1
        results['dns_latency_ms'] = int((time.time() - start) * 1000)
    except Exception as e:
        results['dns_connectivity'] = 0
        results['dns_latency_ms'] = -1
        print(f"DNS connectivity failed: {e}")

    # Publish metrics
    cloudwatch.put_metric_data(
        Namespace='NetworkingDemo',
        MetricData=[
            {'MetricName': 'CrossVpcConnectivity', 'Value': results['ip_connectivity'], 'Unit': 'Count'},
            {'MetricName': 'DnsConnectivity', 'Value': results['dns_connectivity'], 'Unit': 'Count'},
            {'MetricName': 'CrossVpcLatencyMs', 'Value': max(results['dns_latency_ms'], 0), 'Unit': 'Milliseconds'},
        ]
    )

    return results
    PYTHON
    filename = "index.py"
  }
}

resource "aws_cloudwatch_event_rule" "every_minute" {
  provider            = aws.app
  name                = "networking-demo-connectivity-check"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  provider  = aws.app
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "connectivity-check"
  arn       = aws_lambda_function.connectivity_check.arn
}

resource "aws_lambda_permission" "eventbridge" {
  provider      = aws.app
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connectivity_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}

# --- Alarms ---

resource "aws_cloudwatch_metric_alarm" "cross_vpc_connectivity" {
  provider = aws.app

  alarm_name          = "networking-demo-cross-vpc-connectivity-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CrossVpcConnectivity"
  namespace           = "NetworkingDemo"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Cross-VPC connectivity to partner service is down"
  treat_missing_data  = "breaching"

  tags = { Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "dns_connectivity" {
  provider = aws.app

  alarm_name          = "networking-demo-dns-connectivity-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DnsConnectivity"
  namespace           = "NetworkingDemo"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "DNS resolution or connectivity to partner.internal is failing"
  treat_missing_data  = "breaching"

  tags = { Severity = "critical" }
}

resource "aws_cloudwatch_metric_alarm" "cross_vpc_latency" {
  provider = aws.app

  alarm_name          = "networking-demo-cross-vpc-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CrossVpcLatencyMs"
  namespace           = "NetworkingDemo"
  period              = 60
  statistic           = "Average"
  threshold           = 500
  alarm_description   = "Cross-VPC latency to partner service is high (>500ms)"
  treat_missing_data  = "notBreaching"

  tags = { Severity = "warning" }
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy" {
  provider = aws.app

  alarm_name          = "networking-demo-nlb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Partner service NLB has unhealthy targets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.partner.arn_suffix
    TargetGroup  = aws_lb_target_group.partner.arn_suffix
  }

  tags = { Severity = "critical" }
}
