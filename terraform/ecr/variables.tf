variable "aws_region" {
  description = "AWS region for ECR repositories"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "retail-store"
}

variable "services" {
  description = "List of microservices that need ECR repositories"
  type        = list(string)
  default     = ["ui", "catalog", "cart", "orders", "checkout"]
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for repositories"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_days" {
  description = "Number of days to retain untagged images"
  type        = number
  default     = 7
}
