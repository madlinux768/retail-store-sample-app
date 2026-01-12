variable "environment_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_arn" {
  type = string
}

variable "capacity_provider_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "ecs_instance_security_group_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "container_image" {
  type = string
}

variable "service_discovery_namespace_arn" {
  type = string
}

variable "cloudwatch_logs_group_id" {
  type = string
}

variable "healthcheck_path" {
  type    = string
  default = "/health"
}

variable "alb_target_group_arn" {
  type    = string
  default = ""
}

variable "opentelemetry_enabled" {
  type    = bool
  default = false
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secrets" {
  type    = map(string)
  default = {}
}

variable "task_role_policy_arns" {
  type    = list(string)
  default = []
}

variable "cpu" {
  type    = string
  default = "1024"
}

variable "memory" {
  type    = string
  default = "2048"
}
