variable "application_account_id" {
  type        = string
  description = "Application account ID where Development VPC will be deployed"
}

variable "network_services_account_id" {
  type        = string
  description = "Network services account ID"
}

variable "management_account_id" {
  type        = string
  description = "Management account ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "ssh_key_name" {
  description = "Name of the EC2 key pair for SSH access to instances"
  type        = string
}
