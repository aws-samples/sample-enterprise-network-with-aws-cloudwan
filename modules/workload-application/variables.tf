variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the application will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for application deployment"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs (for VPC endpoints)"
  type        = list(string)
  default     = []
}

variable "instance_config" {
  description = "EC2 instance configuration"
  type = object({
    count         = number
    instance_type = string
    key_name      = optional(string)
  })
}

variable "security_config" {
  description = "Security group configuration"
  type = object({
    ingress_rules = list(object({
      from_port       = number
      to_port         = number
      protocol        = string
      description     = string
      cidr_blocks     = optional(list(string))
      security_groups = optional(list(string))
    }))
    egress_rules = list(object({
      from_port       = number
      to_port         = number
      protocol        = string
      description     = string
      cidr_blocks     = optional(list(string))
      security_groups = optional(list(string))
    }))
  })
}

variable "iam_config" {
  description = "IAM configuration"
  type = object({
    instance_profile_name = string
  })
  default = {
    instance_profile_name = ""
  }
}

variable "user_data_config" {
  description = "User data configuration"
  type = object({
    template_file = string
    template_vars = map(string)
  })
}

variable "vpc_endpoints_config" {
  description = "VPC endpoints configuration"
  type = object({
    enabled  = bool
    services = list(string)
  })
  default = {
    enabled  = false
    services = []
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}