variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "enterprise"
}

variable "application_account_id" {
  description = "Application AWS Account ID"
  type        = string
}

variable "network_services_account_id" {
  description = "Network Services AWS Account ID"
  type        = string
}

variable "management_account_id" {
  description = "Management AWS Account ID"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "create_database" {
  description = "Whether to create RDS database"
  type        = bool
  default     = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "register_with_alb" {
  description = "Whether to register instances with ALB target group"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for SSH access to instances"
  type        = string
}
