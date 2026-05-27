variable "namespace_name" {
  type        = string
  description = "Globally unique name of the Azure Service Bus namespace."
}

variable "queue_name" {
  type        = string
  description = "Name of the Azure Service Bus queue created inside the namespace."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group that holds the namespace and queue."
}

variable "location" {
  type        = string
  default     = "westus2"
  description = "Azure region for the resource group, namespace, and queue."
}

variable "sku" {
  type        = string
  default     = "Basic"
  description = "Azure Service Bus namespace SKU. Only the Basic SKU is permitted (cost ceiling, R7.1)."

  validation {
    condition     = var.sku == "Basic"
    error_message = "Only the Basic SKU is permitted (cost ceiling). See requirements R7.1."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every Azure resource in this module that supports tagging. Must include Environment, Project, auto-delete=no, and ManagedBy=Terraform."

  validation {
    condition = alltrue([
      contains(keys(var.tags), "Environment"),
      contains(keys(var.tags), "Project"),
      lookup(var.tags, "auto-delete", "") == "no",
      lookup(var.tags, "ManagedBy", "") == "Terraform",
    ])
    error_message = "tags must include Environment, Project, auto-delete=no, and ManagedBy=Terraform."
  }
}
