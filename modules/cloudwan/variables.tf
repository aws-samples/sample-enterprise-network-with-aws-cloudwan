variable "environment" {
  type        = string
  description = "Environment name"
}

variable "organization_id" {
  type        = string
  description = "AWS Organizations ID"
  default     = null
}

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
}

variable "enabled_regions" {
  type        = list(string)
  description = "List of AWS regions where Cloud WAN should be enabled"
  default     = ["us-east-1", "us-west-2", "ca-central-1"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "resource_prefix" {
  type        = string
  description = "Prefix for resource names. If null, environment will be used"
  default     = null
}

variable "global_network_description" {
  type        = string
  description = "Description for the global network"
  default     = null
}

variable "core_network_description" {
  type        = string
  description = "Description for the core network"
  default     = null
}

variable "network_function_groups_enabled" {
  type    = bool
  default = false
}

variable "segment_config" {
  type = object({
    isolate_attachments           = bool
    require_attachment_acceptance = bool
  })
  default = {
    isolate_attachments           = false
    require_attachment_acceptance = true
  }
}

variable "asn_range" {
  type    = string
  default = "64512-65534"
}

variable "vpn_ecmp_support" {
  type    = bool
  default = true
}

variable "segment_sharing" {
  type = object({
    shared_services_segments = list(string)
  })
  default = {
    shared_services_segments = ["Development", "Production", "UAT", "Hybrid"]
  }
  description = "Configuration for segment sharing"
}

variable "is_primary_region" {
  type        = bool
  description = "Whether this is the primary region deployment"
  default     = false
}

variable "enable_ram_sharing" {
  type        = bool
  description = "Enable RAM sharing for CloudWAN resources"
  default     = true
}

variable "share_with_accounts" {
  type        = list(string)
  description = "List of AWS account IDs to share CloudWAN resources with"
  default     = []
}

# VPC Attachments Configuration (for Network Services Account)
variable "vpc_attachments" {
  type = map(object({
    vpc_arn     = string
    subnet_arns = list(string)
    segment     = string
  }))
  description = "VPC attachments to create for this CloudWAN core network"
  default     = {}
}
