variable "vpc_id" {
  type        = string
  description = "ID of the VPC where DNS resources will be created"
}

variable "subnet_ids" {
  type        = map(string)
  description = "Map of AZ to subnet ID where resolver endpoints will be created"
}

variable "resolver_config" {
  type = object({
    inbound = object({
      enabled = bool
      ip_addresses = optional(list(object({
        subnet_id = string
        ip        = string
      })), [])
    })
    outbound = object({
      enabled = bool
      ip_addresses = optional(list(object({
        subnet_id = string
        ip        = string
      })), [])
      rules = optional(list(object({
        domain_name = string
        target_ips = list(object({
          ip   = string
          port = optional(number, 53)
        }))
        name = optional(string)
      })), [])
    })
  })
  description = "Configuration for Route 53 Resolver endpoints"
}

variable "private_hosted_zones" {
  type = list(object({
    name             = string
    comment          = optional(string)
    force_destroy    = optional(bool, false)
    vpc_associations = optional(list(string), [])
  }))
  description = "List of private hosted zones to create"
  default     = []
}

variable "external_hosted_zones" {
  type = list(object({
    name          = string
    domain_type   = optional(string, "infoblox") # infoblox or other
    ttl           = optional(number, 300)
    record_type   = optional(string, "NS")
    force_destroy = optional(bool, false)
  }))
  description = "List of external hosted zones to be integrated"
  default     = []
}

# Existing variables remain the same

variable "query_logging_config" {
  type = object({
    enabled         = bool
    destination_arn = string
    name            = optional(string)
  })
  description = "Configuration for DNS query logging"
  default = {
    enabled         = false
    destination_arn = null
  }
}

variable "dns_firewall_config" {
  type = object({
    enabled = bool
    rule_groups = optional(list(object({
      name                    = string
      priority                = number
      action                  = string
      block_response          = optional(string, "NODATA")
      block_override_dns_type = optional(string, "CNAME")
      block_override_domain   = optional(string)
      block_override_ttl      = optional(number, 60)
      rules = list(object({
        name        = string
        action      = string
        priority    = number
        domain_list = list(string)
      }))
    })), [])
  })
  description = "Configuration for DNS firewall"
  default = {
    enabled     = false
    rule_groups = []
  }
}

variable "enable_ram_sharing" {
  type        = bool
  description = "Enable RAM sharing for resolver rules"
  default     = false
}

variable "record_sets" {
  type = map(object({
    zone_name = string
    name      = string
    type      = string
    ttl       = number
    records   = list(string)
    alias = optional(object({
      name                   = string
      zone_id                = string
      evaluate_target_health = bool
    }))
  }))
  description = "Record sets to create in hosted zones"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all DNS resources"
  default     = {}
}

variable "endpoint_dns_data" {
  type = object({
    interface_endpoints = map(object({
      service_name   = string
      service        = string
      region         = string
      dns_name       = string
      hosted_zone_id = string
      ip_addresses   = list(string)
    }))
    gateway_endpoints = map(object({
      service_name   = string
      service        = string
      region         = string
      prefix_list_id = string
    }))
  })
  description = "DNS data from VPC endpoints for creating DNS records"
  default = {
    interface_endpoints = {}
    gateway_endpoints   = {}
  }
}