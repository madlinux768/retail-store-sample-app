# UI Service
module "ui_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.1"

  name        = "ui"
  cluster_arn = module.ecs_cluster.arn

  requires_compatibilities = ["MANAGED_INSTANCES"]
  launch_type              = "EC2"

  cpu    = 1024
  memory = 2048

  container_definitions = {
    ui = {
      image     = local.container_images.ui
      essential = true

      port_mappings = [{
        name          = "ui"
        containerPort = 8080
        protocol      = "tcp"
      }]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 10
        startPeriod = 60
        retries     = 3
        timeout     = 5
      }

      environment = [
        { name = "RETAIL_UI_ENDPOINTS_CATALOG", value = "http://catalog" },
        { name = "RETAIL_UI_ENDPOINTS_CARTS", value = "http://cart" },
        { name = "RETAIL_UI_ENDPOINTS_CHECKOUT", value = "http://checkout" },
        { name = "RETAIL_UI_ENDPOINTS_ORDERS", value = "http://orders" }
      ]

      readonly_root_filesystem = false

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ui"
        }
      }
    }
  }

  capacity_provider_strategy = {
    managed = {
      capacity_provider = module.ecs_cluster.capacity_providers["managed-instances"].name
      weight            = 1
      base              = 1
    }
  }

  load_balancer = {
    ui = {
      target_group_arn = module.alb.target_groups["ui"].arn
      container_name   = "ui"
      container_port   = 8080
    }
  }

  subnet_ids = module.vpc.inner.private_subnets

  service_connect_configuration = {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.this.arn
    service = [{
      client_alias = {
        dns_name = "ui"
        port     = 80
      }
      discovery_name = "ui"
      port_name      = "ui"
    }]
  }

  enable_execute_command = true

  tags = module.tags.result
}

# Catalog Service
module "catalog_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.1"

  name        = "catalog"
  cluster_arn = module.ecs_cluster.arn

  requires_compatibilities = ["MANAGED_INSTANCES"]
  launch_type              = "EC2"

  cpu    = 512
  memory = 1024

  container_definitions = {
    catalog = {
      image     = local.container_images.catalog
      essential = true

      port_mappings = [{
        name          = "catalog"
        containerPort = 8080
        protocol      = "tcp"
      }]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 10
        startPeriod = 60
        retries     = 3
        timeout     = 5
      }

      environment = [
        { name = "DB_ENDPOINT", value = module.dependencies.catalog_db_endpoint },
        { name = "DB_NAME", value = module.dependencies.catalog_db_database_name },
        { name = "DB_USER", value = module.dependencies.catalog_db_master_username },
        { name = "DB_PASSWORD", value = module.dependencies.catalog_db_master_password }
      ]

      readonly_root_filesystem = false

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "catalog"
        }
      }
    }
  }

  capacity_provider_strategy = {
    managed = {
      capacity_provider = module.ecs_cluster.capacity_providers["managed-instances"].name
      weight            = 1
    }
  }

  subnet_ids = module.vpc.inner.private_subnets

  service_connect_configuration = {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.this.arn
    service = [{
      client_alias = {
        dns_name = "catalog"
        port     = 80
      }
      discovery_name = "catalog"
      port_name      = "catalog"
    }]
  }

  enable_execute_command = true

  tags = module.tags.result
}

# Cart Service
module "cart_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.1"

  name        = "cart"
  cluster_arn = module.ecs_cluster.arn

  requires_compatibilities = ["MANAGED_INSTANCES"]
  launch_type              = "EC2"

  cpu    = 512
  memory = 1024

  container_definitions = {
    cart = {
      image     = local.container_images.cart
      essential = true

      port_mappings = [{
        name          = "cart"
        containerPort = 8080
        protocol      = "tcp"
      }]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 10
        startPeriod = 60
        retries     = 3
        timeout     = 5
      }

      environment = [
        { name = "CARTS_DYNAMODB_TABLENAME", value = module.dependencies.carts_dynamodb_table_name }
      ]

      readonly_root_filesystem = false

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "cart"
        }
      }
    }
  }

  capacity_provider_strategy = {
    managed = {
      capacity_provider = module.ecs_cluster.capacity_providers["managed-instances"].name
      weight            = 1
    }
  }

  subnet_ids = module.vpc.inner.private_subnets

  service_connect_configuration = {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.this.arn
    service = [{
      client_alias = {
        dns_name = "cart"
        port     = 80
      }
      discovery_name = "cart"
      port_name      = "cart"
    }]
  }

  tasks_iam_role_policies = {
    dynamodb = module.dependencies.carts_dynamodb_policy_arn
  }

  enable_execute_command = true

  tags = module.tags.result
}

# Orders Service  
module "orders_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.1"

  name        = "orders"
  cluster_arn = module.ecs_cluster.arn

  requires_compatibilities = ["MANAGED_INSTANCES"]
  launch_type              = "EC2"

  cpu    = 1024
  memory = 2048

  container_definitions = {
    orders = {
      image     = local.container_images.orders
      essential = true

      port_mappings = [{
        name          = "orders"
        containerPort = 8080
        protocol      = "tcp"
      }]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval    = 10
        startPeriod = 60
        retries     = 3
        timeout     = 5
      }

      environment = [
        { name = "SPRING_DATASOURCE_URL", value = "jdbc:postgresql://${module.dependencies.orders_db_endpoint}:${module.dependencies.orders_db_port}/${module.dependencies.orders_db_database_name}" },
        { name = "SPRING_DATASOURCE_USERNAME", value = module.dependencies.orders_db_master_username },
        { name = "SPRING_DATASOURCE_PASSWORD", value = module.dependencies.orders_db_master_password },
        { name = "SPRING_RABBITMQ_HOST", value = split(":", module.dependencies.mq_broker_endpoint)[0] },
        { name = "SPRING_RABBITMQ_PORT", value = split(":", module.dependencies.mq_broker_endpoint)[1] },
        { name = "SPRING_RABBITMQ_USERNAME", value = module.dependencies.mq_user },
        { name = "SPRING_RABBITMQ_PASSWORD", value = module.dependencies.mq_password }
      ]

      readonly_root_filesystem = false

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "orders"
        }
      }
    }
  }

  capacity_provider_strategy = {
    managed = {
      capacity_provider = module.ecs_cluster.capacity_providers["managed-instances"].name
      weight            = 1
    }
  }

  subnet_ids = module.vpc.inner.private_subnets

  service_connect_configuration = {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.this.arn
    service = [{
      client_alias = {
        dns_name = "orders"
        port     = 80
      }
      discovery_name = "orders"
      port_name      = "orders"
    }]
  }

  enable_execute_command = true

  tags = module.tags.result
}

# Checkout Service
module "checkout_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.1"

  name        = "checkout"
  cluster_arn = module.ecs_cluster.arn

  requires_compatibilities = ["MANAGED_INSTANCES"]
  launch_type              = "EC2"

  cpu    = 512
  memory = 1024

  container_definitions = {
    checkout = {
      image     = local.container_images.checkout
      essential = true

      port_mappings = [{
        name          = "checkout"
        containerPort = 8080
        protocol      = "tcp"
      }]

      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 10
        startPeriod = 60
        retries     = 3
        timeout     = 5
      }

      environment = [
        { name = "REDIS_URL", value = "redis://${module.dependencies.checkout_elasticache_primary_endpoint}:${module.dependencies.checkout_elasticache_port}" },
        { name = "ENDPOINTS_ORDERS", value = "http://orders" }
      ]

      readonly_root_filesystem = false

      log_configuration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "checkout"
        }
      }
    }
  }

  capacity_provider_strategy = {
    managed = {
      capacity_provider = module.ecs_cluster.capacity_providers["managed-instances"].name
      weight            = 1
    }
  }

  subnet_ids = module.vpc.inner.private_subnets

  service_connect_configuration = {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.this.arn
    service = [{
      client_alias = {
        dns_name = "checkout"
        port     = 80
      }
      discovery_name = "checkout"
      port_name      = "checkout"
    }]
  }

  enable_execute_command = true

  tags = module.tags.result
}
