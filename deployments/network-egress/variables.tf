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



variable "egress_config" {
  type = object({
    nat_gateway = object({
      enabled = bool
      per_az  = bool
    })
    gwlb_endpoints = object({
      checkpoint = object({
        enabled = bool
      })
      zscaler = object({
        enabled = bool
      })
    })
    waf = object({
      enabled = bool
    })
  })
}



# Removed vpc_cidr and aws_cidr_range_x variables - now using data sources



variable "network_core_account_id" {
  type        = string
  description = "Network core account ID"
}

variable "network_services_account_id" {
  type        = string
  description = "Network services account ID (where egress resources will be created)"
}

variable "security_account_id" {
  type        = string
  description = "Security account ID (where inspection services are deployed)"
}

variable "management_account_id" {
  type        = string
  description = "Management account ID (where Terraform runs)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
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