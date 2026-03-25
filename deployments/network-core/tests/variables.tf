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

variable "enabled_regions" {
  type        = list(string)
  description = "List of enabled AWS regions"
}

variable "pool_configuration" {
  type = object({
    pool_cidrs              = map(string)
    enable_hybrid_pools     = bool
    enable_inspection_pools = bool
    enable_firewall_pools   = bool
  })
  description = "IPAM pool configuration"
}

variable "regional_config" {
  type = map(object({
    cidrs             = list(string)
    connectivity_type = string
    pool_priority     = string
  }))
  description = "Regional configuration for IPAM"
}

variable "enable_ram_sharing" {
  type        = bool
  description = "Enable RAM sharing"
  default     = true
}

variable "enable_logging" {
  type        = bool
  description = "Enable logging"
  default     = true
}

variable "log_retention_days" {
  type        = number
  description = "Log retention days"
  default     = 90
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "subnet_configuration" {
  type = map(object({
    type               = string
    cidr_blocks        = list(string)
    availability_zones = list(string)
    public_ip          = optional(bool, false)
    route_table_config = optional(object({
      create_per_az = optional(bool, false)
      routes = optional(list(object({
        destination = string
        target_type = string
        target_id   = string
      })), [])
    }))
  }))
  description = "Subnet configuration for the VPC"
}

variable "vpc_endpoints" {
  type = map(object({
    service             = string
    service_type        = string
    private_dns_enabled = optional(bool, true)
    policy              = optional(string)
    security_group_ids  = optional(list(string))
  }))
  description = "Map of VPC endpoint configurations"
}

variable "resolver_config" {
  type = object({
    outbound = object({
      rules = list(object({
        domain_name = string
        target_ips = list(object({
          ip   = string
          port = optional(number, 53)
        }))
      }))
    })
  })
  description = "Route 53 Resolver configuration"
}

variable "private_hosted_zones" {
  type = list(object({
    name             = string
    comment          = optional(string)
    force_destroy    = optional(bool, false)
    vpc_associations = optional(list(string), [])
  }))
  description = "List of private hosted zones"
}

variable "external_hosted_zones" {
  type = list(object({
    name          = string
    domain_type   = optional(string, "infoblox")
    ttl           = optional(number, 300)
    record_type   = optional(string, "NS")
    force_destroy = optional(bool, false)
  }))
  description = "List of external hosted zones"
}

variable "management_account_role_arn" {
  type        = string
  description = "Role ARN for organization management account"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

