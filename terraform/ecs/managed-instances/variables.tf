variable "environment_name" {
  type        = string
  default     = "retail-store-ecs-mi"
  description = "Name of the environment"
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region for deployment"
}

variable "container_image_repository" {
  type        = string
  description = "ECR repository prefix (e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com/retail-store)"
}

variable "container_image_tag" {
  type        = string
  default     = "latest"
  description = "Container image tag to deploy"
}

variable "container_insights_setting" {
  type        = string
  default     = "enhanced"
  description = "Container Insights setting for ECS cluster (enhanced or disabled)"

  validation {
    condition     = contains(["enhanced", "disabled"], var.container_insights_setting)
    error_message = "container_insights_setting must be either 'enhanced' or 'disabled'"
  }
}

variable "opentelemetry_enabled" {
  type        = bool
  default     = false
  description = "Enable OpenTelemetry tracing"
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "Instance types for ECS Managed Instances"
}

variable "min_size" {
  type        = number
  default     = 2
  description = "Minimum number of instances"
}

variable "max_size" {
  type        = number
  default     = 10
  description = "Maximum number of instances"
}

variable "desired_size" {
  type        = number
  default     = 3
  description = "Desired number of instances"
}
