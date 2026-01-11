output "repository_urls" {
  description = "Map of service names to ECR repository URLs"
  value = {
    for service, repo in aws_ecr_repository.services :
    service => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of service names to ECR repository ARNs"
  value = {
    for service, repo in aws_ecr_repository.services :
    service => repo.arn
  }
}

output "registry_id" {
  description = "ECR registry ID"
  value       = data.aws_caller_identity.current.account_id
}

output "repository_names" {
  description = "List of ECR repository names"
  value       = [for repo in aws_ecr_repository.services : repo.name]
}
