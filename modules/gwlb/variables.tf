variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where GWLB will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "gwlb_subnet_ids" {
  description = "List of subnet IDs for GWLB (one per AZ)"
  type        = list(string)
}

variable "router_subnet_ids" {
  description = "List of subnet IDs for router instances (one per AZ)"
  type        = list(string)
}

variable "gwlb_endpoint_subnets" {
  description = "Map of AZ to subnet ID for GWLB endpoints"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for router instances (Amazon Linux 2023 recommended)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Instance type for router instances"
  type        = string
  default     = "t3.small"
}

variable "min_instances" {
  description = "Minimum number of router instances"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of router instances"
  type        = number
  default     = 6
}

variable "desired_instances" {
  description = "Desired number of router instances"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
