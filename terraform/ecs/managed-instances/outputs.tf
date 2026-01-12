output "application_url" {
  description = "URL where the application can be accessed"
  value       = "http://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "capacity_provider_name" {
  description = "Name of the ECS Managed Instances capacity provider"
  value       = aws_ecs_capacity_provider.managed_instances.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.inner.vpc_id
}

output "service_names" {
  description = "Names of all ECS services"
  value = {
    ui       = module.ui_service.service_name
    catalog  = module.catalog_service.service_name
    cart     = module.cart_service.service_name
    orders   = module.orders_service.service_name
    checkout = module.checkout_service.service_name
  }
}
