output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.core_vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.core_vpc.vpc_cidr
}

output "subnet_ids" {
  description = "Map of subnet IDs by type"
  value       = module.core_vpc.subnets
}

output "route_table_ids" {
  description = "Map of route table IDs by type"
  value       = module.core_vpc.route_tables
}

output "endpoint_ids" {
  description = "Map of VPC endpoint IDs"
  value       = module.endpoints.endpoint_ids
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "dns_endpoints" {
  description = "DNS endpoints information"
  value = {
    inbound  = try(module.dns.resolver_endpoints.inbound, null)
    outbound = try(module.dns.resolver_endpoints.outbound, null)
  }
}

output "ipam_details" {
  value = var.is_primary_region ? module.ipam[0].ipam_details : null
}

output "core_network_id" {
  description = "ID of the Cloud WAN core network"
  value       = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id
}

output "core_network_arn" {
  description = "ARN of the Cloud WAN core network"
  value       = var.is_primary_region ? module.cloudwan[0].core_network_arn : null
}

output "endpoints_debug" {
  value = module.endpoints.debug
}

output "ipam_allocations" {
  value = {
    vpc     = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
    subnets = local.flat_subnets # Use calculated subnets 
    # resolver_ips = {
    #   for type, allocations in aws_vpc_ipam_pool_cidr_allocation.resolver_ips : type => allocations[*].cidr
    # }
  }
}

output "subnet_debug" {
  value = {
    vpc_cidr           = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
    vpc_netmask_length = tonumber(split("/", aws_vpc_ipam_pool_cidr_allocation.vpc.cidr)[1])
    subnet_types       = local.subnet_types
    azs_count          = length(local.azs)
    subnet_calculation_example = {
      type_index_example  = index(local.subnet_types, "private")
      az_count            = length(local.azs)
      calculation_example = index(local.subnet_types, "private") * length(local.azs) + 0
    }
    subnet_cidrs = local.subnet_cidrs
    flat_subnets_sample = {
      private_0 = try(local.flat_subnets["private-0"], null)
      private_1 = try(local.flat_subnets["private-1"], null)
      transit_0 = try(local.flat_subnets["transit-0"], null)
    }
  }
}

output "regional_ipam_pools" {
  value = var.is_primary_region ? (
    try(module.ipam[0].ipam_details.pools.network.regional_pools, {})
  ) : null
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account network read role"
  value       = var.is_primary_region ? aws_iam_role.network_core_read[0].arn : null
}

output "cloudwan_ram_share_arn" {
  description = "ARN of the CloudWAN RAM resource share"
  value       = var.is_primary_region ? module.cloudwan[0].ram_resource_share_arn : null
}

output "cloudwan_ram_share_id" {
  description = "ID of the CloudWAN RAM resource share"
  value       = var.is_primary_region ? module.cloudwan[0].ram_resource_share_id : null
}
# Shared VPC Outputs
output "shared_production_vpc" {
  description = "Shared production VPC details"
  value = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["production"].enabled, false) ? {
    vpc_id                 = module.shared_production_vpc[0].vpc_id
    vpc_cidr               = module.shared_production_vpc[0].vpc_cidr_block
    vpc_arn                = module.shared_production_vpc[0].vpc_arn
    private_subnet_ids     = module.shared_production_vpc[0].subnets["private"]
    transit_subnet_ids     = module.shared_production_vpc[0].subnets["transit"]
    database_subnet_ids    = try(module.shared_production_vpc[0].subnets["database"], {})
    ram_share_arn          = module.shared_production_vpc[0].ram_share_arn
    cloudwan_attachment_id = module.shared_production_vpc[0].cloudwan_attachment_id
  } : null
}

output "shared_development_vpc" {
  description = "Shared development VPC details"
  value = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["development"].enabled, false) ? {
    vpc_id                 = module.shared_development_vpc[0].vpc_id
    vpc_cidr               = module.shared_development_vpc[0].vpc_cidr_block
    vpc_arn                = module.shared_development_vpc[0].vpc_arn
    private_subnet_ids     = module.shared_development_vpc[0].subnets["private"]
    transit_subnet_ids     = module.shared_development_vpc[0].subnets["transit"]
    ram_share_arn          = module.shared_development_vpc[0].ram_share_arn
    cloudwan_attachment_id = module.shared_development_vpc[0].cloudwan_attachment_id
  } : null
}

output "shared_staging_vpc" {
  description = "Shared staging VPC details"
  value = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["staging"].enabled, false) ? {
    vpc_id                 = module.shared_staging_vpc[0].vpc_id
    vpc_cidr               = module.shared_staging_vpc[0].vpc_cidr_block
    vpc_arn                = module.shared_staging_vpc[0].vpc_arn
    private_subnet_ids     = module.shared_staging_vpc[0].subnets["private"]
    transit_subnet_ids     = module.shared_staging_vpc[0].subnets["transit"]
    ram_share_arn          = module.shared_staging_vpc[0].ram_share_arn
    cloudwan_attachment_id = module.shared_staging_vpc[0].cloudwan_attachment_id
  } : null
}

output "shared_vpcs_summary" {
  description = "Summary of all shared VPCs created"
  value = var.create_shared_workload_vpcs ? {
    enabled = var.create_shared_workload_vpcs
    vpcs_created = [
      for vpc_name, vpc_config in var.shared_workload_vpcs : vpc_name
      if vpc_config.enabled
    ]
    total_shared_accounts = length(distinct(flatten([
      for vpc_name, vpc_config in var.shared_workload_vpcs : vpc_config.share_with_accounts
      if vpc_config.enabled
    ])))
  } : null
}