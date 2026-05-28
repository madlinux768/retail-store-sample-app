# Azure Service Bus integration for the orders service.
#
# Every resource in this file is gated on var.azure_servicebus_enabled. When
# the flag is false (the default), the entire file is a no-op and the AWS-side
# plan is byte-for-byte identical to the pre-feature plan (verified explicitly
# by task 14.3 in the implementation plan).
#
# When the flag is true, this file:
#   1. Provisions the Azure Service Bus namespace + queue + send-only SAS rule
#      via the terraform/lib/azure-servicebus module.
#   2. Stores the resulting send-only connection string in AWS Secrets Manager.
#   3. Generates a short random suffix for the globally-unique Azure namespace
#      name.
#
# The orders task definition (orders.tf) wires the secret into the container
# via the ECS `secrets` block and extends the orders task IAM policy to allow
# secretsmanager:GetSecretValue against this new secret only.

resource "random_string" "azure_ns" {
  count = var.azure_servicebus_enabled ? 1 : 0

  length  = 6
  special = false
  upper   = false
}

module "azure_servicebus" {
  count  = var.azure_servicebus_enabled ? 1 : 0
  source = "../azure-servicebus"

  namespace_name      = "${var.environment_name}-orders-${random_string.azure_ns[0].result}"
  queue_name          = "orders-events"
  resource_group_name = "${var.environment_name}-orders-rg"
  location            = "westus2"
  tags                = var.tags
}

resource "aws_secretsmanager_secret" "azure_servicebus" {
  count = var.azure_servicebus_enabled ? 1 : 0

  name = "${var.environment_name}-orders-azure-servicebus-${random_string.random_orders_secret.result}"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "azure_servicebus" {
  count = var.azure_servicebus_enabled ? 1 : 0

  secret_id     = aws_secretsmanager_secret.azure_servicebus[0].id
  secret_string = jsonencode({ connectionString = module.azure_servicebus[0].primary_connection_string })
}
