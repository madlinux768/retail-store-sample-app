variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "app_account_id" {
  description = "AWS account ID of the application account"
  type        = string
  default     = "173471018689"
}

variable "networking_account_id" {
  description = "AWS account ID of the networking account (where VPC2 + TGW live)"
  type        = string
  default     = "378147474529"
}

variable "app_vpc_id" {
  description = "VPC ID of the application VPC in the app account"
  type        = string
}

variable "app_private_subnet_ids" {
  description = "Private subnet IDs in the app VPC for TGW attachment"
  type        = list(string)
}

variable "partner_vpc_cidr" {
  description = "CIDR block for the partner VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "app_vpc_cidr" {
  description = "CIDR block of the app VPC (for route back)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "partner_instance_type" {
  description = "EC2 instance type for the partner service"
  type        = string
  default     = "t3.micro"
}

variable "networking_role_arn" {
  description = "IAM role ARN to assume for the networking account"
  type        = string
}

variable "app_route_table_id" {
  description = "Route table ID in the app VPC for the TGW route"
  type        = string
}
