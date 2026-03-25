variable "region" {
  type        = string
  description = "AWS region where endpoints will be created"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where endpoints will be created"
}

variable "subnet_ids" {
  type        = map(string)
  description = "Map of AZ to subnet ID where interface endpoints will be created"
}

variable "route_table_ids" {
  type        = list(string)
  description = "List of route table IDs to associate with gateway endpoints"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all endpoint resources"
  default     = {}
}

variable "endpoint_services" {
  type        = list(string)
  description = "List of AWS service names to create endpoints for (e.g., ['events', 's3', 'lambda'])"
  default     = []
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for VPC endpoints"
}

# New variables for GWLB endpoint support
variable "gwlb_endpoints" {
  type = list(object({
    name               = string
    service_name       = optional(string) # Direct service name
    ssm_parameter_name = optional(string) # SSM parameter containing service name
    ssm_json_path      = optional(string) # JSON path within SSM parameter (e.g., "security_services.zscaler.endpoint_service_name")
    subnet_ids         = list(string)     # Specific subnets for this GWLB endpoint
  }))
  description = "List of GWLB endpoints to create"
  default     = []
}


