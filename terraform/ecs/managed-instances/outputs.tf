output "application_url" {
  description = "URL where the application can be accessed"
  value       = "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

output "capacity_provider_name" {
  description = "Name of the ECS Managed Instances capacity provider"
  value       = module.ecs_cluster.capacity_providers["managed-instances"].name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.inner.vpc_id
}

output "service_names" {
  description = "Names of all ECS services"
  value = {
    ui       = module.ui_service.name
    catalog  = module.catalog_service.name
    cart     = module.cart_service.name
    orders   = module.orders_service.name
    checkout = module.checkout_service.name
  }
}
