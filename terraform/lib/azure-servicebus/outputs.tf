output "primary_connection_string" {
  value       = azurerm_servicebus_queue_authorization_rule.send_only.primary_connection_string
  sensitive   = true
  description = "Primary connection string for the send-only queue SAS rule. Consume into AWS Secrets Manager; never log."
}

output "namespace_id" {
  value       = azurerm_servicebus_namespace.this.id
  description = "Resource ID of the Azure Service Bus namespace."
}

output "queue_id" {
  value       = azurerm_servicebus_queue.orders_events.id
  description = "Resource ID of the Azure Service Bus queue."
}
