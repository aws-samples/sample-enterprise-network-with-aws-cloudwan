variable "environment" {
  type        = string
  description = "Environment name"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
}

variable "is_primary_region" {
  type        = bool
  description = "Whether this is the primary region"
}

variable "enabled_regions" {
  type        = list(string)
  description = "List of enabled regions"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "security_config" {
  type = object({
    checkpoint = object({
      enabled          = bool
      instance_type    = string
      desired_capacity = number
      max_size         = number
      min_size         = number
    })
    aws_network_firewall = object({
      enabled     = bool
      policy_name = string
    })
    gwlb = object({
      enabled     = bool
      target_port = number
      health_check = object({
        enabled             = bool
        healthy_threshold   = number
        interval            = number
        matcher             = optional(string)
        path                = optional(string)
        port                = string
        protocol            = string
        timeout             = number
        unhealthy_threshold = number
      })
    })
    zscaler = object({
      enabled          = bool
      instance_type    = optional(string, "t3.medium")
      desired_capacity = optional(number, 2)
      max_size         = optional(number, 4)
      min_size         = optional(number, 1)
    })
  })
  description = "Security inspection configuration"
}

variable "subnet_netmasks" {
  type        = map(number)
  description = "Map of subnet types to netmask lengths"
  validation {
    condition = alltrue([
      for netmask in values(var.subnet_netmasks) : netmask >= 16 && netmask <= 28
    ])
    error_message = "Subnet netmask lengths must be between 16 and 28."
  }
}

variable "vpc_netmask_length" {
  type        = number
  description = "VPC CIDR netmask length"
  default     = 22
  validation {
    condition     = var.vpc_netmask_length >= 16 && var.vpc_netmask_length <= 24
    error_message = "VPC netmask length must be between 16 and 24."
  }
}

variable "network_core_account_id" {
  type        = string
  description = "Network core account ID"
}

variable "security_account_id" {
  type        = string
  description = "Security account ID where inspection services will be deployed"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "checkpoint_password" {
  description = "CheckPoint admin password. Must be provided at deploy time — do not store in source control."
  type        = string
  sensitive   = true
}

variable "checkpoint_sic_key" {
  description = "CheckPoint SIC (Secure Internal Communication) key. Must be provided at deploy time — do not store in source control."
  type        = string
  sensitive   = true
}

variable "checkpoint_password_hash" {
  description = "Pre-computed password hash for CheckPoint admin user. Generate with: openssl passwd -1 'yourpassword'. Must be provided at deploy time."
  type        = string
  sensitive   = true
}
