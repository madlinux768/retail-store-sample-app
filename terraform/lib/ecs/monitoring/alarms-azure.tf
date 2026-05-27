resource "aws_cloudwatch_metric_alarm" "orders_azure_publish_failures" {
  count = var.azure_servicebus_enabled ? 1 : 0

  alarm_name          = "${var.environment_name}-orders-azure-publish-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "OrdersAzurePublishFailures"
  namespace           = "RetailStore/Orders"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Orders service failed to publish to Azure Service Bus. Cross-cloud dependency: Azure Service Bus (westus2). Investigate via DevOps Agent. Runbook: https://wiki.example.com/runbooks/orders-azure-publish"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.warning.arn]
  ok_actions    = [aws_sns_topic.warning.arn]
  tags          = var.tags
}
