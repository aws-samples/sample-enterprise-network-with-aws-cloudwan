

data "aws_region" "current" {
  provider = aws.network-services
}
data "aws_caller_identity" "current" {
  provider = aws.network-services
}

# Locals removed - flow logs now managed by VPC module

# RAM resource share discovery (organization-level sharing) - Optional
# data "aws_ram_resource_share" "ipam_pools" {
#   name           = "${var.environment}-ipam-pools"
#   resource_owner = "OTHER-ACCOUNTS"
# }

# IPAM pool lookup for egress VPC
data "aws_vpc_ipam_pool" "egress_regional" {
  provider = aws.network-services

  filter {
    name   = "tag:Name"
    values = ["network-${var.region}-ipam-pool"]
  }
}

locals {
  name_prefix     = "${substr(var.environment, 0, 8)}-${substr(var.region, -1, 1)}${substr(var.region, -3, 1)}-egrs" # e.g., "[ENVIRONMENT]-[REGION]-egrs"
  ipam_pool_id    = data.aws_vpc_ipam_pool.egress_regional.id
  core_network_id = data.aws_ssm_parameter.core_network_id.value

  # Define static CIDR ranges for CloudWAN routing (these should match your IPAM configuration)
  aws_cidr_ranges = [
    "10.0.0.0/8" # Your organization's main CIDR block
  ]

  # Create CloudWAN routes for each global CIDR block
  cloudwan_routes = [
    for cidr in local.aws_cidr_ranges : {
      destination = cidr
      target_type = "cloudwan"
      target_id   = local.core_network_id
    }
  ]

  # Dynamic subnet configuration from variables
  subnet_configuration = {
    for type, netmask in var.subnet_netmasks : type => {
      type           = type
      netmask_length = netmask
    }
  }

  # Route configuration map for different subnet types
  route_configs = {
    public   = { internet_gateway = true, gwlb_endpoint = false, nat_gateway = false }
    firewall = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = true }  # ✓ Firewall routes to NAT for egress
    transit  = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = false } # Transit routes to Network Firewall (configured separately)
  }

  # Extract netmasks for CIDR calculation
  subnet_netmasks = {
    for type, config in local.subnet_configuration : type => config.netmask_length
  }

  # Subnet types from subnet configuration
  subnet_types = keys(local.subnet_configuration)

  # Validate subnet netmasks against VPC size
  _validate_subnets = {
    for type, netmask in var.subnet_netmasks :
    type => netmask >= var.vpc_netmask_length ? netmask :
    error("Subnet ${type} netmask (${netmask}) must be >= VPC netmask (${var.vpc_netmask_length})")
  }
}

# IPAM Allocations
# VPC CIDR allocation (kept in deployment for subnet CIDR calculation)
resource "aws_vpc_ipam_pool_cidr_allocation" "vpc" {
  provider       = aws.network-services
  ipam_pool_id   = local.ipam_pool_id
  netmask_length = var.vpc_netmask_length
}

locals {
  azs      = var.availability_zones
  vpc_cidr = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr

  # CIDR calculation with environment-specific netmasks
  flat_subnets = {
    for pair in setproduct(local.subnet_types, range(length(local.azs))) :
    "${pair[0]}-${pair[1]}" => cidrsubnet(
      local.vpc_cidr,
      local.subnet_netmasks[pair[0]] - var.vpc_netmask_length,
      index(local.subnet_types, pair[0]) * length(local.azs) + pair[1]
    )
  }

  # Group by type → list of CIDRs per AZ
  subnet_cidrs = {
    for type in local.subnet_types :
    type => [
      for az_index in range(length(local.azs)) :
      local.flat_subnets["${type}-${az_index}"]
    ]
  }
}

# Egress VPC Module
module "egress_vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.network-services
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 30

  # CloudWAN Configuration - module creates attachment
  cloudwan_config = {
    enabled                 = true
    core_network_id         = local.core_network_id
    core_network_account_id = var.network_services_account_id
    segment                 = "egress"
    attachment_tags = {
      nfg          = "egressinspection"
      account-type = "network-egress"
      approved-by  = "network-team"
    }
  }

  # CloudWAN Routes - DISABLED when Network Firewall is enabled
  # Network Firewall module manages all routes including CloudWAN routes
  cloudwan_routes = local.enable_network_firewall ? {} : {
    transit  = local.aws_cidr_ranges # Transit subnet routes back to workload VPCs
    firewall = local.aws_cidr_ranges # Firewall subnet routes back to workload VPCs
  }

  vpc_configuration = {
    name         = "${var.environment}-egress-vpc"
    type         = "egress"
    category     = "networking"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr # Use IPAM-allocated CIDR
    region       = var.region
    account_type = "network-egress"
    environment  = var.environment

    subnet_configuration = {
      for type in local.subnet_types : type => {
        type               = type
        cidr_blocks        = local.subnet_cidrs[type]
        availability_zones = var.availability_zones
        route_table_config = {
          routes = concat([
            # Local VPC route (always present)
            {
              destination = local.vpc_cidr
              target_type = "local"
              target_id   = "" # Local routes don't need target_id
            }
            ],
            # Internet route via IGW for public subnets
            local.route_configs[type].internet_gateway ? [{
              destination = "0.0.0.0/0"
              target_type = "internet_gateway"
              target_id   = "igw-placeholder" # Will be replaced with actual IGW
            }] : [],
            # Internet route via NAT Gateway for transit and firewall subnets
            local.route_configs[type].nat_gateway ? [{
              destination = "0.0.0.0/0"
              target_type = "nat_gateway"
              target_id   = "nat-placeholder" # Will be replaced with actual NAT gateway
            }] : [],
            # GWLB endpoint route (conditional) - only if CheckPoint enabled
            local.route_configs[type].gwlb_endpoint && var.egress_config.gwlb_endpoints.checkpoint.enabled ? [{
              destination = "0.0.0.0/0"
              target_type = "gateway_load_balancer_endpoint"
              target_id   = "gwlb-endpoint-placeholder" # Will be replaced with actual endpoint
            }] : [],
            # CloudWAN routes for transit and firewall subnets to route back to workload VPCs
          (type == "transit" || type == "firewall") ? local.cloudwan_routes : [])
        }
      }
    }

    features = {
      enable_dns_hostnames    = true
      enable_dns_support      = true
      enable_flow_logs        = true # Enable flow logs (module creates resources)
      enable_nat_gateway      = true # Enable NAT gateway for internet egress
      enable_internet_gateway = true
      create_igw              = true # Explicitly create IGW
    }

    tags = var.tags
  }
}



# KMS key for SSM parameter encryption (CKV_AWS_337)
resource "aws_kms_key" "ssm_parameters" {
  provider                = aws.network-services
  description             = "KMS key for SSM parameter encryption in egress VPC"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ssm-parameters"
  })
}

resource "aws_kms_alias" "ssm_parameters" {
  provider      = aws.network-services
  name          = "alias/${var.environment}-egress-ssm-parameters"
  target_key_id = aws_kms_key.ssm_parameters.key_id
}

# Store egress details in SSM Parameter Store
resource "aws_ssm_parameter" "egress_config" {
  provider = aws.network-services

  name        = "/aft/network/egress/config"
  description = "Egress VPC configuration for workload accounts"
  type        = "SecureString"
  key_id      = aws_kms_key.ssm_parameters.id
  value = jsonencode({
    vpc_details = {
      vpc_id   = module.egress_vpc.vpc_id
      vpc_cidr = module.egress_vpc.vpc_cidr
      subnets  = module.egress_vpc.subnets
    }
    security_services = {
      checkpoint = {
        status = "gwlb-endpoint"
        type   = "checkpoint-endpoint"
      }
      zscaler = var.egress_config.gwlb_endpoints.zscaler.enabled ? {
        status = "gwlb-endpoint"
        type   = "zscaler-endpoint"
      } : null
    }
    environment = var.environment
  })

  tags = var.tags
}

# Store egress attachment ID for CloudWAN static routes (now from module output)
resource "aws_ssm_parameter" "egress_attachment_id" {
  provider = aws.network-services

  name        = "/aft/network/egress/cloudwan-attachment-id"
  description = "Egress VPC CloudWAN attachment ID for static routes"
  type        = "String"
  key_id      = aws_kms_key.ssm_parameters.id
  value       = module.egress_vpc.cloudwan_attachment_id

  tags = var.tags
}

# Routes are now managed by the network_firewall module
# The module handles:
# - Transit subnet routes (CloudWAN → Firewall)
# - Firewall subnet routes (Firewall → CloudWAN/NAT)
# - Public subnet return routes (NAT → Firewall → CloudWAN) for symmetric routing
# See network-firewall.tf for route configuration
