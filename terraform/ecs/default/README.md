# AWS Containers Retail Sample - ECS Terraform (Default)

This Terraform module creates all the necessary infrastructure and deploys the retail sample application on [Amazon Elastic Container Service](https://aws.amazon.com/ecs/).

It provides:

- VPC with public and private subnets
- ECS cluster using Fargate for compute
- All application dependencies such as RDS, DynamoDB table, Elasticache etc.
- Deployment of application components as ECS services
- ECS Service Connect to handle traffic between services
- Optional OpenTelemetry integration for observability
- Configurable Container Insights settings
- Optional Azure Service Bus messaging provider for the orders service (cross-cloud demo, off by default)

NOTE: This will create resources in your AWS account which will incur costs. You are responsible for these costs, and should understand the resources being created before proceeding.

## Usage

Pre-requisites for this are:

- AWS, Terraform and kubectl installed locally
- AWS CLI configured and authenticated with account to deploy to

After cloning this repository run the following commands:

```shell
cd terraform/ecs/default

terraform init
terraform plan
terraform apply
```

The final command will prompt for confirmation that you wish to create the specified resources. After confirming the process will take at least 15 minutes to complete. You can then retrieve the HTTP endpoint for the UI from Terraform outputs:

```shell
terraform output -raw application_url
```

Enter the URL in a web browser to access the application.

## Azure Service Bus Cross-Cloud Demo

This stack can optionally provision an Azure Service Bus namespace and configure the orders service to publish events to it instead of the in-AWS messaging provider. The feature is gated by `azure_servicebus_enabled` (default `false`); the AWS-side plan is byte-identical to the flag-off case when the flag is off.

Pre-requisites:

- Azure CLI installed locally
- Authenticated against the demo subscription:

  ```shell
  az login
  az account set --subscription fc9c11a5-8e06-4a8f-a173-2cfa7972f511
  ```

To enable, set the following in `terraform.tfvars`:

```hcl
azure_servicebus_enabled = true
```

Then run `terraform plan` and `terraform apply` as usual. The plan should add one Azure resource group, one Service Bus namespace (sku=Basic), one queue, one send-only SAS rule, plus an AWS Secrets Manager secret holding the connection string and an IAM policy update granting the orders task role read access to that secret.

To disable, set `azure_servicebus_enabled = false` (or remove the line) and apply. Azure resources are destroyed; AWS state returns to the byte-identical baseline.

See `.kiro/specs/azure-service-bus-messaging-provider/` for the full design.

## Reference

This section documents the variables and outputs of the Terraform configuration.

### Inputs

| Name                         | Description                                                                                                                                               | Type     | Default            | Required |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------ | :------: |
| `environment_name`           | Name of the environment which will be used for all resources created                                                                                      | `string` | `retail-store-ecs` |   yes    |
| `opentelemetry_enabled`      | Flag to enable OpenTelemetry, which will install the AWS Distro for OpenTelemetry and configure trace collection                                          | `bool`   | `false`            |    no    |
| `container_insights_setting` | Container Insights setting for ECS cluster. Must be either 'enhanced' or 'disabled'. When OpenTelemetry is enabled, defaults to 'enhanced'                | `string` | `disabled`         |    no    |
| `lifecycle_events_enabled`   | Enable ECS lifecycle events to CloudWatch Logs for Container Insights performance dashboard. Only available when container_insights_setting is 'enhanced' | `bool`   | `false`            |    no    |
| `log_group_retention_days`   | Number of days to retain logs in CloudWatch Log Groups                                                                                                    | `number` | `30`               |    no    |

### Outputs

| Name              | Description                               |
| ----------------- | ----------------------------------------- |
| `application_url` | URL where the application can be accessed |
