# Network Firewall Module Variables

variable "name_prefix" {
  description = "Prefix for resource names (e.g., '[ENVIRONMENT]-[REGION]-egrs')"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Network Firewall will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where firewall endpoints will be deployed (one per AZ)"
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "rule_order" {
  description = "Rule order for stateful engine (DEFAULT_ACTION_ORDER or STRICT_ORDER)"
  type        = string
  default     = "DEFAULT_ACTION_ORDER"

  validation {
    condition     = contains(["DEFAULT_ACTION_ORDER", "STRICT_ORDER"], var.rule_order)
    error_message = "Rule order must be either DEFAULT_ACTION_ORDER or STRICT_ORDER."
  }
}

variable "custom_rule_group_arns" {
  description = "List of custom rule group ARNs to add to the firewall policy"
  type        = list(string)
  default     = []
}

variable "enable_test_block_rules" {
  description = "Enable test blocking rules for validation (blocks facebook.com, twitter.com, instagram.com, 8.8.8.8, 8.8.4.4, port 22)"
  type        = bool
  default     = false
}

variable "custom_block_rules" {
  description = "List of custom blocking rules"
  type = list(object({
    name        = string
    source      = string
    destination = string
    description = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_drop_established" {
  description = "Enable drop_established action to block non-matching traffic (recommended for production)"
  type        = bool
  default     = false
}

variable "enable_alert_established" {
  description = "Enable alert_established to log ALERT_ESTABLISHED messages for packets in established connections"
  type        = bool
  default     = false
}

variable "allowed_domains" {
  description = "List of allowed domain patterns for internet access (e.g., '.google.com', '.github.com')"
  type        = list(string)
  default     = []
}

variable "blocked_domains" {
  description = "List of blocked domain patterns (e.g., '.facebook.com', '.twitter.com') - generates ALERT logs"
  type        = list(string)
  default     = []
}


# Route Management Variables
variable "manage_routes" {
  description = "Whether to manage routes for Network Firewall integration"
  type        = bool
  default     = false
}

variable "route_table_ids" {
  description = "Map of route table IDs to manage (e.g., {transit = 'rtb-xxx', firewall = 'rtb-yyy'})"
  type        = map(string)
  default     = {}
}

variable "transit_routes" {
  description = "List of routes for transit subnet to firewall"
  type = list(object({
    destination_cidr_block = string
    description            = optional(string)
  }))
  default = []
}

variable "firewall_routes" {
  description = "List of routes for firewall subnet (e.g., to CloudWAN, NAT Gateway)"
  type = list(object({
    destination_cidr_block = string
    target_type            = string # cloudwan, nat_gateway, internet_gateway
    target_id              = optional(string)
    description            = optional(string)
  }))
  default = []
}

variable "public_return_routes" {
  description = "List of return routes for public subnet (for asymmetric routing fix)"
  type = list(object({
    destination_cidr_block = string
    description            = optional(string)
  }))
  default = []
}

variable "core_network_arn" {
  description = "CloudWAN Core Network ARN (required if using CloudWAN routes)"
  type        = string
  default     = null
}

variable "nat_gateway_id" {
  description = "NAT Gateway ID (required if firewall routes to NAT)"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ID for Network Firewall encryption (CKV_AWS_345, CKV_AWS_346)"
  type        = string
  default     = null
}
