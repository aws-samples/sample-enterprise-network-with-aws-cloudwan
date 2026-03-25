output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.network_core.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.network_core.vpc_cidr
}

output "subnet_ids" {
  description = "Map of subnet IDs by type"
  value       = module.network_core.subnet_ids
}

output "route_table_ids" {
  description = "Map of route table IDs by type"
  value       = module.network_core.route_table_ids
}

output "endpoint_ids" {
  description = "Map of VPC endpoint IDs"
  value       = module.network_core.endpoint_ids
}

output "dns_endpoints" {
  description = "DNS endpoints information"
  value       = module.network_core.dns_endpoints
}

output "ipam_details" {
  description = "IPAM Configuration Details"
  value       = module.network_core.ipam_details
}

# Testing helper outputs
output "availability_zones_used" {
  description = "List of availability zones used in the VPC"
  value       = var.availability_zones
}

output "resolver_config" {
  description = "Route 53 resolver configuration used"
  value       = var.resolver_config
}

output "private_hosted_zones" {
  description = "Private hosted zones configuration"
  value       = var.private_hosted_zones
}

output "vpc_endpoints_config" {
  description = "VPC endpoints configuration"
  value       = var.vpc_endpoints
}

output "environment" {
  description = "Environment name used in testing"
  value       = var.environment
}

output "region" {
  description = "Region used in testing"
  value       = var.region
}

output "tags" {
  description = "Tags applied to resources"
  value       = var.tags
}

