# azure-servicebus

Terraform module that provisions the minimal Azure Service Bus footprint used
by the orders service for the cross-cloud DevOps Agent demo: one resource
group, one namespace at SKU `Basic`, one queue, and one send-only queue-scoped
SAS authorization rule.

This is a leaf module. It is consumed by `terraform/lib/ecs/orders-azure.tf`
behind the `azure_servicebus_enabled` feature flag (see the parent ECS module
for wiring details).

## Resources created

| Resource                                      | Notes                                                                                                                             |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `azurerm_resource_group`                      | Holds the namespace and queue. Tagged.                                                                                            |
| `azurerm_servicebus_namespace`                | SKU is locked to `Basic` by variable validation. Tagged.                                                                          |
| `azurerm_servicebus_queue`                    | Single queue. **Not tagged** — the AzureRM resource has no `tags` attribute. Documented exception to the repository tagging rule. |
| `azurerm_servicebus_queue_authorization_rule` | `send=true, listen=false, manage=false`. The namespace-level `RootManageSharedAccessKey` is intentionally not used.               |

## Authentication

The module uses the AzureRM provider, which authenticates the operator (or CI
job) running `terraform plan`/`apply` against Azure. There is no in-module
credential — the caller is responsible for providing one.

### Demo (current path)

```bash
az login
az account set --subscription fc9c11a5-8e06-4a8f-a173-2cfa7972f511
terraform init
terraform plan
terraform apply
```

`az login` populates the local Azure CLI cache, and the AzureRM provider
picks up that cache automatically. This is the path used for the cross-cloud
demo described in `azure-service-bus-messaging-provider/design.md`.

### Federated identity for CI (follow-up, not implemented)

For unattended `terraform apply` from GitHub Actions, the recommended approach
is OpenID Connect federation to an Azure AD app registration with the
`Contributor` role scoped to the resource group. The AzureRM provider supports
this through the `use_oidc` argument and the `ARM_OIDC_TOKEN`,
`ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_SUBSCRIPTION_ID` environment
variables that GitHub injects into the workflow.

This is intentionally out of scope for the initial demo and is captured as a
follow-up in the open questions section of the design document.

## Variable contract

| Input                 | Type        | Required | Default   | Constraint                                                                                      |
| --------------------- | ----------- | -------- | --------- | ----------------------------------------------------------------------------------------------- |
| `namespace_name`      | string      | yes      | —         | Must be globally unique across Azure.                                                           |
| `queue_name`          | string      | yes      | —         |                                                                                                 |
| `resource_group_name` | string      | yes      | —         |                                                                                                 |
| `location`            | string      | no       | `westus2` |                                                                                                 |
| `sku`                 | string      | no       | `Basic`   | Validation rejects any value other than `Basic` (cost ceiling, R7.1).                           |
| `tags`                | map(string) | yes      | —         | Must contain keys `Environment` and `Project`, plus `auto-delete=no` and `ManagedBy=Terraform`. |

## Outputs

| Output                      | Type   | Sensitive | Use                                                                                                                 |
| --------------------------- | ------ | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `primary_connection_string` | string | yes       | Push into AWS Secrets Manager and inject into the orders ECS task via the `secrets =` block. Never log, never echo. |
| `namespace_id`              | string | no        | Reference for downstream Azure resources or audit.                                                                  |
| `queue_id`                  | string | no        | Reference for downstream Azure resources or audit.                                                                  |

## Notes

- The queue resource does not support `tags` at the AzureRM API level. Tags
  are applied to every parent resource that does support them (the resource
  group and the namespace). This is a documented exception to the repository
  tagging rule.
- The send-only SAS rule is the smallest credential surface that lets the
  orders service publish. A leaked key cannot read the queue, manage the
  queue, or touch any other queue in the namespace.
- TLS is implicit. The Azure SDK uses AMQPS over TLS by default when given an
  `Endpoint=sb://` connection string; the orders provider does not override
  the transport.
