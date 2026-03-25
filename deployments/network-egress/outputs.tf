output "vpc_id" {
  description = "ID of the egress VPC"
  value       = module.egress_vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the egress VPC"
  value       = local.vpc_cidr
}

output "subnet_ids" {
  description = "Map of subnet type to subnet IDs"
  value       = module.egress_vpc.subnets
}

output "route_table_ids" {
  description = "Map of subnet type to route table IDs"
  value       = module.egress_vpc.route_table_ids
}

output "core_network_id" {
  description = "CloudWAN Core Network ID"
  value       = local.core_network_id
  sensitive   = true
}

output "cwan_attachment_id" {
  description = "CloudWAN VPC attachment ID"
  value       = module.egress_vpc.cloudwan_attachment_id
}

output "subnet_configuration" {
  description = "Subnet configuration used by the module"
  value       = local.subnet_configuration
}

output "global_cidr_ranges" {
  description = "Global CIDR ranges from IPAM pool"
  value       = local.aws_cidr_ranges
}