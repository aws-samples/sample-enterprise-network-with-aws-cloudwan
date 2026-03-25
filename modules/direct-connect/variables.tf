variable "environment" {
  type        = string
  description = "Environment name"
}

variable "core_network_id" {
  type        = string
  description = "CloudWAN Core Network ID"
}

variable "dx_connection_id" {
  type        = string
  description = "Direct Connect connection ID (if available)"
  default     = null
}

variable "dx_gateway_asn" {
  type        = number
  description = "BGP ASN for the Direct Connect Gateway (AWS side)"
  default     = 64512

  validation {
    condition     = var.dx_gateway_asn >= 64512 && var.dx_gateway_asn <= 65534
    error_message = "DX Gateway ASN must be in the private ASN range (64512-65534)."
  }
}

variable "customer_bgp_asn" {
  type        = number
  description = "Customer BGP ASN for the VIF"
  default     = 65000

  validation {
    condition     = var.customer_bgp_asn >= 1 && var.customer_bgp_asn <= 4294967294 && var.customer_bgp_asn != 64512
    error_message = "Customer BGP ASN must be a valid ASN (1-4294967294) and different from the default DX Gateway ASN (64512)."
  }
}

variable "vlan_id" {
  type        = number
  description = "VLAN ID for the private VIF"
  default     = 100

  validation {
    condition     = var.vlan_id >= 1 && var.vlan_id <= 4094
    error_message = "VLAN ID must be between 1 and 4094."
  }
}

variable "bgp_auth_key" {
  type        = string
  description = "BGP authentication key (optional)"
  default     = null
  sensitive   = true
}

variable "allowed_prefixes" {
  type        = list(string)
  description = "List of allowed prefixes for DX Gateway association"
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}