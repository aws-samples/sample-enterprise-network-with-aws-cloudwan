variable "environment" {
  type        = string
  description = "Environment name (e.g., prod)"
}

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
}

variable "enabled_regions" {
  type        = list(string)
  description = "List of AWS regions to enable IPAM in"
}

variable "pool_configuration" {
  type = object({
    pool_cidrs              = map(string) # All CIDR blocks will be provided via map
    enable_hybrid_pools     = bool
    enable_inspection_pools = bool
    enable_firewall_pools   = bool
  })
  description = "IPAM pool configuration including CIDRs and feature flags"
}

# variable "regional_config" {
#   type = map(object({
#     cidrs = list(string)
#     connectivity_type = string
#     pool_priority = string
#   }))
#   description = "Regional configuration for IPAM pools"
# }

variable "regional_config" {
  type = map(object({
    cidrs             = list(string) # Only network pool CIDRs needed
    connectivity_type = string
    pool_priority     = string
  }))
  description = "Regional configuration for IPAM pools"
}


variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "enable_ram_sharing" {
  type        = bool
  description = "Enable RAM sharing of IPAM pools"
  default     = true
}
