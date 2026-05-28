resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_servicebus_namespace" "this" {
  name                = var.namespace_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = var.sku
  tags                = var.tags
}

# Note: azurerm_servicebus_queue does not expose a `tags` attribute at the
# AzureRM API level, so the queue itself is intentionally untagged. Tags are
# applied to every parent resource that supports them (the resource group and
# the namespace). See design.md for the documented exception to R3.3.
resource "azurerm_servicebus_queue" "orders_events" {
  name         = var.queue_name
  namespace_id = azurerm_servicebus_namespace.this.id
}

# Send-only queue-scoped SAS rule. Listen and Manage are explicitly disabled
# so a leaked key can only publish to this single queue. The namespace-level
# RootManageSharedAccessKey is intentionally not used by the orders service.
resource "azurerm_servicebus_queue_authorization_rule" "send_only" {
  name     = "${var.queue_name}-send"
  queue_id = azurerm_servicebus_queue.orders_events.id
  send     = true
  listen   = false
  manage   = false
}
