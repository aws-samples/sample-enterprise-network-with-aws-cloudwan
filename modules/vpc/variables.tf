variable "is_primary_region" {
  description = "Whether this is the primary region"
  type        = bool
  default     = false
}

variable "create_flow_log_resources" {
  description = "Whether to create CloudWatch log group and IAM role for VPC flow logs (set to false if using existing resources)"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Number of days to retain VPC flow logs"
  type        = number
  default     = 7
}

variable "create_flow_log_role" {
  description = "Whether to create the IAM role for VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_log_role_name" {
  description = "Name of the IAM role for VPC flow logs"
  type        = string
  default     = null
}

variable "ipam_allocation" {
  description = "IPAM allocation configuration - if enabled, module will allocate CIDR from IPAM pool"
  type = object({
    enabled        = optional(bool, false)
    ipam_pool_id   = optional(string)
    netmask_length = optional(number)
  })
  default = {
    enabled        = false
    ipam_pool_id   = null
    netmask_length = null
  }
}

variable "vpc_configuration" {
  type = object({
    name         = string
    type         = string
    category     = string
    cidr_block   = optional(string) # Required if ipam_allocation.enabled = false
    ipam_pool_id = optional(string) # Deprecated - use ipam_allocation instead
    region       = string
    account_type = string
    environment  = string

    subnet_configuration = map(object({
      type               = string
      cidr_blocks        = optional(list(string)) # These will come from IPAM allocations
      availability_zones = list(string)
      route_table_config = optional(object({
        routes = list(object({
          destination = string
          target_type = string
          target_id   = string
        }))
      }))
    }))

    features = object({
      enable_dns_hostnames = bool
      enable_dns_support   = bool
      enable_flow_logs     = bool
      enable_nat_gateway   = optional(bool, false) # Enable NAT Gateway
      create_igw           = optional(bool, false) # Create Internet Gateway
      flow_logs_config = optional(object({
        traffic_type  = string
        log_group_arn = string # ARN of existing CloudWatch log group
        iam_role_arn  = string # ARN of existing IAM role
      }))
      dhcp_options = optional(object({
        enabled              = optional(bool, true)
        domain_name          = optional(string) # Defaults to region-based if not provided
        domain_name_servers  = optional(list(string), ["AmazonProvidedDNS"])
        ntp_servers          = optional(list(string))
        netbios_name_servers = optional(list(string))
        netbios_node_type    = optional(number)
      }))
    })

    tags = map(string)
  })
  description = "VPC configuration including IPAM settings"
}

# CloudWAN Configuration
variable "cloudwan_config" {
  type = object({
    enabled                 = optional(bool, false)
    core_network_id         = optional(string, null)
    core_network_account_id = optional(string, null) # Account where Core Network exists
    segment                 = optional(string, "production")
    auto_accept             = optional(bool, true)
    attachment_tags         = optional(map(string), {}) # Additional tags for CloudWAN attachment
    wait_for_policy         = optional(bool, false)     # Wait for CloudWAN policy propagation (for network-core)
    policy_wait_duration    = optional(string, "30s")   # Duration to wait for policy propagation
  })
  description = "CloudWAN attachment configuration"
  default = {
    enabled                 = false
    core_network_id         = null
    core_network_account_id = null
    segment                 = "production"
    auto_accept             = true
    attachment_tags         = {}
    wait_for_policy         = false
    policy_wait_duration    = "30s"
  }
}

variable "cloudwan_routes" {
  description = "CloudWAN routes to create after attachment - map of subnet_type to list of CIDR blocks"
  type        = map(list(string))
  default     = {}
  # Example:
  # {
  #   private  = ["10.0.0.0/8", "0.0.0.0/0"]
  #   database = ["10.0.0.0/8"]
  #   transit  = ["10.0.0.0/8", "0.0.0.0/0"]
  # }
}

# RAM Sharing Configuration
variable "ram_sharing_config" {
  type = object({
    enabled             = optional(bool, false)
    share_name          = optional(string, null)
    share_with_accounts = optional(list(string), [])
    share_with_org      = optional(bool, false)
    organization_id     = optional(string, null)
  })
  description = "RAM resource sharing configuration"
  default = {
    enabled             = false
    share_name          = null
    share_with_accounts = []
    share_with_org      = false
    organization_id     = null
  }
}






