variable "is_primary_region" {
  type        = bool
  description = "Whether this is the primary region deployment"
  default     = false
}

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

# Keep IPAM configuration
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
    subnet_mask_bits  = optional(number, 16)
    region_index      = optional(number, 0)
    connectivity_type = string
    pool_priority     = string
  }))
  description = "Regional configuration for IPAM pools with dynamic CIDR calculation"
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

# Remove vpc_cidr as it will come from IPAM

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

# Update subnet_configuration to remove cidr_blocks
variable "subnet_configuration" {
  type = map(object({
    type               = string
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

variable "endpoint_services" {
  type        = list(string)
  description = "List of AWS service names to create endpoints for"
  default     = []
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
  default     = 21
  validation {
    condition     = var.vpc_netmask_length >= 16 && var.vpc_netmask_length <= 24
    error_message = "VPC netmask length must be between 16 and 24."
  }
}

# Add IPAM pool ID for non-primary regions
variable "ipam_pool_id" {
  type        = string
  description = "IPAM pool ID for non-primary regions"
  default     = null
}

variable "core_network_id" {
  description = "ID of the core network (required for non-primary regions)"
  type        = string
  default     = null
}

variable "organization_arn" {
  description = "Organization ARN"
  type        = string
  default     = null
}

variable "organization_id" {
  type        = string
  description = "AWS Organization ID"
  default     = null
}

variable "management_account_id" {
  type        = string
  description = "AWS Organization Management Account ID"
}

variable "network_services_account_id" {
  type        = string
  description = "AWS Network Services Account ID (where IPAM will be deployed)"
}

variable "share_with_accounts" {
  type        = list(string)
  description = "List of AWS account IDs to share CloudWAN resources with"
  default     = []
}

variable "dx_config" {
  type = object({
    enabled          = bool
    connection_id    = optional(string)
    gateway_asn      = optional(number, 64512)
    customer_bgp_asn = optional(number, 65000)
    vlan_id          = optional(number, 100)
    bgp_auth_key     = optional(string)
    allowed_prefixes = optional(list(string), ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"])
  })
  description = "Direct Connect configuration"
  default = {
    enabled = false
  }
}

# Shared Workload VPCs Configuration
variable "create_shared_workload_vpcs" {
  type        = bool
  description = "Whether to create shared workload VPCs in the network services account"
  default     = false
}

variable "shared_workload_vpcs" {
  type = map(object({
    enabled            = bool
    segment            = string
    category           = string
    vpc_netmask_length = number
    subnet_configuration = map(object({
      type               = string
      availability_zones = list(string)
    }))
    share_with_accounts = list(string)
  }))
  description = "Configuration for shared workload VPCs"
  default     = {}
}