# Container image configuration
locals {
  container_images = {
    ui       = "${var.container_image_repository}-ui:${var.container_image_tag}"
    catalog  = "${var.container_image_repository}-catalog:${var.container_image_tag}"
    cart     = "${var.container_image_repository}-cart:${var.container_image_tag}"
    orders   = "${var.container_image_repository}-orders:${var.container_image_tag}"
    checkout = "${var.container_image_repository}-checkout:${var.container_image_tag}"
  }
}

# UI Service
module "ui_service" {
  source = "./service"

  environment_name                = var.environment_name
  service_name                    = "ui"
  cluster_arn                     = aws_ecs_cluster.this.arn
  capacity_provider_name          = aws_ecs_capacity_provider.managed_instances.name
  vpc_id                          = module.vpc.inner.vpc_id
  subnet_ids                      = module.vpc.inner.private_subnets
  ecs_instance_security_group_id  = aws_security_group.ecs_instances.id
  tags                            = module.tags.result
  container_image                 = local.container_images.ui
  service_discovery_namespace_arn = aws_service_discovery_private_dns_namespace.this.arn
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/actuator/health"
  alb_target_group_arn            = aws_lb_target_group.ui.arn
  opentelemetry_enabled           = var.opentelemetry_enabled

  environment_variables = {
    RETAIL_UI_ENDPOINTS_CATALOG  = "http://catalog"
    RETAIL_UI_ENDPOINTS_CARTS    = "http://cart"
    RETAIL_UI_ENDPOINTS_CHECKOUT = "http://checkout"
    RETAIL_UI_ENDPOINTS_ORDERS   = "http://orders"
  }
}

# Catalog Service
module "catalog_service" {
  source = "./service"

  environment_name                = var.environment_name
  service_name                    = "catalog"
  cluster_arn                     = aws_ecs_cluster.this.arn
  capacity_provider_name          = aws_ecs_capacity_provider.managed_instances.name
  vpc_id                          = module.vpc.inner.vpc_id
  subnet_ids                      = module.vpc.inner.private_subnets
  ecs_instance_security_group_id  = aws_security_group.ecs_instances.id
  tags                            = module.tags.result
  container_image                 = local.container_images.catalog
  service_discovery_namespace_arn = aws_service_discovery_private_dns_namespace.this.arn
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/health"
  opentelemetry_enabled           = var.opentelemetry_enabled

  environment_variables = {
    DB_ENDPOINT = module.dependencies.catalog_db_endpoint
    DB_NAME     = module.dependencies.catalog_db_database_name
    DB_USER     = module.dependencies.catalog_db_master_username
  }

  secrets = {
    DB_PASSWORD = module.dependencies.catalog_db_secret_arn
  }
}

# Cart Service
module "cart_service" {
  source = "./service"

  environment_name                = var.environment_name
  service_name                    = "cart"
  cluster_arn                     = aws_ecs_cluster.this.arn
  capacity_provider_name          = aws_ecs_capacity_provider.managed_instances.name
  vpc_id                          = module.vpc.inner.vpc_id
  subnet_ids                      = module.vpc.inner.private_subnets
  ecs_instance_security_group_id  = aws_security_group.ecs_instances.id
  tags                            = module.tags.result
  container_image                 = local.container_images.cart
  service_discovery_namespace_arn = aws_service_discovery_private_dns_namespace.this.arn
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/actuator/health"
  opentelemetry_enabled           = var.opentelemetry_enabled

  task_role_policy_arns = [module.dependencies.carts_dynamodb_policy_arn]

  environment_variables = {
    CARTS_DYNAMODB_TABLENAME = module.dependencies.carts_dynamodb_table_name
  }
}

# Orders Service
module "orders_service" {
  source = "./service"

  environment_name                = var.environment_name
  service_name                    = "orders"
  cluster_arn                     = aws_ecs_cluster.this.arn
  capacity_provider_name          = aws_ecs_capacity_provider.managed_instances.name
  vpc_id                          = module.vpc.inner.vpc_id
  subnet_ids                      = module.vpc.inner.private_subnets
  ecs_instance_security_group_id  = aws_security_group.ecs_instances.id
  tags                            = module.tags.result
  container_image                 = local.container_images.orders
  service_discovery_namespace_arn = aws_service_discovery_private_dns_namespace.this.arn
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/actuator/health"
  opentelemetry_enabled           = var.opentelemetry_enabled

  environment_variables = {
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${module.dependencies.orders_db_endpoint}:${module.dependencies.orders_db_port}/${module.dependencies.orders_db_database_name}"
    SPRING_DATASOURCE_USERNAME = module.dependencies.orders_db_master_username
    SPRING_RABBITMQ_HOST       = split(":", module.dependencies.mq_broker_endpoint)[0]
    SPRING_RABBITMQ_PORT       = split(":", module.dependencies.mq_broker_endpoint)[1]
    SPRING_RABBITMQ_USERNAME   = module.dependencies.mq_user
  }

  secrets = {
    SPRING_DATASOURCE_PASSWORD = module.dependencies.orders_db_secret_arn
    SPRING_RABBITMQ_PASSWORD   = module.dependencies.mq_secret_arn
  }
}

# Checkout Service
module "checkout_service" {
  source = "./service"

  environment_name                = var.environment_name
  service_name                    = "checkout"
  cluster_arn                     = aws_ecs_cluster.this.arn
  capacity_provider_name          = aws_ecs_capacity_provider.managed_instances.name
  vpc_id                          = module.vpc.inner.vpc_id
  subnet_ids                      = module.vpc.inner.private_subnets
  ecs_instance_security_group_id  = aws_security_group.ecs_instances.id
  tags                            = module.tags.result
  container_image                 = local.container_images.checkout
  service_discovery_namespace_arn = aws_service_discovery_private_dns_namespace.this.arn
  cloudwatch_logs_group_id        = aws_cloudwatch_log_group.ecs_tasks.id
  healthcheck_path                = "/health"
  opentelemetry_enabled           = var.opentelemetry_enabled

  environment_variables = {
    REDIS_URL       = "redis://${module.dependencies.checkout_elasticache_primary_endpoint}:${module.dependencies.checkout_elasticache_port}"
    ENDPOINTS_ORDERS = "http://orders"
  }
}
