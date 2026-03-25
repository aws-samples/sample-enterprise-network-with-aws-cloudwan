# Shared Workload VPCs
# These VPCs are created in the Network Services Account and shared via RAM

# IPAM Allocations for Shared VPCs
resource "aws_vpc_ipam_pool_cidr_allocation" "shared_vpcs" {
  provider = aws.network-services
  for_each = var.create_shared_workload_vpcs ? var.shared_workload_vpcs : {}

  depends_on     = [module.ipam]
  ipam_pool_id   = try(module.ipam[0].ipam_details.pools.workload.regional_pools[var.region].id, var.ipam_pool_id)
  netmask_length = each.value.vpc_netmask_length
}

locals {
  # Calculate subnet CIDRs for each shared VPC
  shared_vpc_subnets = {
    for vpc_name, vpc_config in var.shared_workload_vpcs : vpc_name => {
      vpc_cidr = var.create_shared_workload_vpcs ? aws_vpc_ipam_pool_cidr_allocation.shared_vpcs[vpc_name].cidr : ""

      # Calculate subnet CIDRs dynamically
      subnet_cidrs = var.create_shared_workload_vpcs ? {
        for subnet_type, subnet_config in vpc_config.subnet_configuration : subnet_type => [
          for az_index in range(length(subnet_config.availability_zones)) :
          cidrsubnet(
            aws_vpc_ipam_pool_cidr_allocation.shared_vpcs[vpc_name].cidr,
            26 - vpc_config.vpc_netmask_length, # /26 subnets
            index(keys(vpc_config.subnet_configuration), subnet_type) * length(subnet_config.availability_zones) + az_index
          )
        ]
      } : {}
    } if var.create_shared_workload_vpcs && vpc_config.enabled
  }
}

# Shared Production VPC
module "shared_production_vpc" {
  count  = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["production"].enabled, false) ? 1 : 0
  source = "../../modules/vpc"

  providers = {
    aws = aws.network-services
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 7

  vpc_configuration = {
    name         = "${var.environment}-shared-production-vpc"
    type         = "workload"
    category     = "production"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.shared_vpcs["production"].cidr
    region       = var.region
    account_type = "shared-workload"
    environment  = var.environment

    subnet_configuration = {
      for subnet_type, subnet_config in var.shared_workload_vpcs["production"].subnet_configuration : subnet_type => {
        type               = subnet_config.type
        cidr_blocks        = local.shared_vpc_subnets["production"].subnet_cidrs[subnet_type]
        availability_zones = subnet_config.availability_zones
        route_table_config = {
          routes = subnet_config.type == "transit" ? [] : [
            # Add routes for non-transit subnets if needed
          ]
        }
      }
    }

    features = {
      enable_dns_hostnames = true
      enable_dns_support   = true
      enable_flow_logs     = true # Enable flow logs (module creates resources)
    }

    tags = merge(var.tags, {
      SharedVPC = "true"
      Segment   = "production"
      VPCType   = "shared-workload"
    })
  }

  # CloudWAN Configuration
  cloudwan_config = {
    enabled         = true
    core_network_id = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id
    segment         = var.shared_workload_vpcs["production"].segment
    auto_accept     = true
  }

  # RAM Sharing Configuration
  ram_sharing_config = {
    enabled             = true
    share_name          = "${var.environment}-shared-production-vpc"
    share_with_accounts = var.shared_workload_vpcs["production"].share_with_accounts
  }
}

# Shared Development VPC
module "shared_development_vpc" {
  count  = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["development"].enabled, false) ? 1 : 0
  source = "../../modules/vpc"

  providers = {
    aws = aws.network-services
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 7

  vpc_configuration = {
    name         = "${var.environment}-shared-development-vpc"
    type         = "workload"
    category     = "development"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.shared_vpcs["development"].cidr
    region       = var.region
    account_type = "shared-workload"
    environment  = var.environment

    subnet_configuration = {
      for subnet_type, subnet_config in var.shared_workload_vpcs["development"].subnet_configuration : subnet_type => {
        type               = subnet_config.type
        cidr_blocks        = local.shared_vpc_subnets["development"].subnet_cidrs[subnet_type]
        availability_zones = subnet_config.availability_zones
        route_table_config = {
          routes = subnet_config.type == "transit" ? [] : []
        }
      }
    }

    features = {
      enable_dns_hostnames = true
      enable_dns_support   = true
      enable_flow_logs     = true # Enable flow logs (module creates resources)
    }

    tags = merge(var.tags, {
      SharedVPC = "true"
      Segment   = "development"
      VPCType   = "shared-workload"
    })
  }

  cloudwan_config = {
    enabled         = true
    core_network_id = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id
    segment         = var.shared_workload_vpcs["development"].segment
    auto_accept     = true
  }

  ram_sharing_config = {
    enabled             = true
    share_name          = "${var.environment}-shared-development-vpc"
    share_with_accounts = var.shared_workload_vpcs["development"].share_with_accounts
  }
}

# Shared Staging VPC
module "shared_staging_vpc" {
  count  = var.create_shared_workload_vpcs && try(var.shared_workload_vpcs["staging"].enabled, false) ? 1 : 0
  source = "../../modules/vpc"

  providers = {
    aws = aws.network-services
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 7

  vpc_configuration = {
    name         = "${var.environment}-shared-staging-vpc"
    type         = "workload"
    category     = "staging"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.shared_vpcs["staging"].cidr
    region       = var.region
    account_type = "shared-workload"
    environment  = var.environment

    subnet_configuration = {
      for subnet_type, subnet_config in var.shared_workload_vpcs["staging"].subnet_configuration : subnet_type => {
        type               = subnet_config.type
        cidr_blocks        = local.shared_vpc_subnets["staging"].subnet_cidrs[subnet_type]
        availability_zones = subnet_config.availability_zones
        route_table_config = {
          routes = subnet_config.type == "transit" ? [] : []
        }
      }
    }

    features = {
      enable_dns_hostnames = true
      enable_dns_support   = true
      enable_flow_logs     = true # Enable flow logs (module creates resources)
    }

    tags = merge(var.tags, {
      SharedVPC = "true"
      Segment   = var.shared_workload_vpcs["staging"].segment
      VPCType   = "shared-workload"
    })
  }

  cloudwan_config = {
    enabled         = true
    core_network_id = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id
    segment         = var.shared_workload_vpcs["staging"].segment
    auto_accept     = true
  }

  ram_sharing_config = {
    enabled             = true
    share_name          = "${var.environment}-shared-staging-vpc"
    share_with_accounts = var.shared_workload_vpcs["staging"].share_with_accounts
  }
}