data "aws_region" "current" {
  provider = aws.network-services
}
data "aws_caller_identity" "current" {
  provider = aws.network-services
}
data "aws_organizations_organization" "current" {
  provider = aws.org-management
}

# Data source for IPAM pool when not in primary region
data "aws_vpc_ipam_pool" "network" {
  provider = aws.network-services
  count    = var.is_primary_region ? 0 : 1

  filter {
    name   = "tag:Name"
    values = ["network-${var.region}-ipam-pool"]
  }

  filter {
    name   = "locale"
    values = [var.region]
  }
}

locals {
  name_prefix = "${substr(var.environment, 0, 8)}-${substr(var.region, -1, 1)}${substr(var.region, -3, 1)}-core" # e.g., "[ENVIRONMENT]-[REGION]-core"
  # Use regional network pool for proper IPAM hierarchy
  ipam_pool_id = var.is_primary_region ? (
    try(module.ipam[0].ipam_details.pools.network.regional_pools[var.region].id, var.ipam_pool_id)
  ) : data.aws_vpc_ipam_pool.network[0].id
}

# Global resources - only created in primary region
# IPAM Organization Admin Account - must be created before IPAM
# This enables the network services account as delegated admin for IPAM
resource "aws_vpc_ipam_organization_admin_account" "main" {
  provider                   = aws.org-management
  count                      = var.is_primary_region ? 1 : 0
  delegated_admin_account_id = var.network_services_account_id
}

# IPAM Module
module "ipam" {
  count  = var.is_primary_region ? 1 : 0
  source = "../../modules/ipam"

  depends_on = [aws_vpc_ipam_organization_admin_account.main]

  providers = {
    aws                = aws.network-services
    aws.primary_region = aws.network-services
    aws.org-management = aws.org-management
  }
  #organization_arn = var.organization_arn
  environment        = var.environment
  primary_region     = var.primary_region
  enabled_regions    = var.enabled_regions
  pool_configuration = var.pool_configuration
  regional_config    = var.regional_config
  enable_ram_sharing = var.enable_ram_sharing
  # enable_logging     = var.enable_logging
  # log_retention_days = var.log_retention_days
  tags = var.tags
}

# Cloud WAN Module
module "cloudwan" {
  count  = var.is_primary_region ? 1 : 0
  source = "../../modules/cloudwan"

  providers = {
    aws = aws.network-services
  }
  depends_on        = [module.ipam]
  environment       = var.environment
  is_primary_region = var.is_primary_region
  #organization_id     = var.organization_id
  primary_region      = var.primary_region
  enabled_regions     = var.enabled_regions
  share_with_accounts = var.share_with_accounts
  tags                = var.tags
}

# IPAM Allocations
# VPC CIDR allocation - allocate directly from parent network pool
resource "aws_vpc_ipam_pool_cidr_allocation" "vpc" {
  provider       = aws.network-services
  depends_on     = [module.ipam]
  ipam_pool_id   = local.ipam_pool_id
  netmask_length = var.vpc_netmask_length
}

locals {
  azs      = var.availability_zones
  vpc_cidr = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr

  # Dynamic subnet configuration from variables
  subnet_configuration = {
    for type, netmask in var.subnet_netmasks : type => {
      type           = type
      netmask_length = netmask
    }
  }

  # Extract netmasks for CIDR calculation
  subnet_netmasks = {
    for type, config in local.subnet_configuration : type => config.netmask_length
  }

  # Subnet types from subnet configuration
  subnet_types = keys(local.subnet_configuration)

  # CIDR calculation with configurable netmasks
  flat_subnets = {
    for pair in setproduct(local.subnet_types, range(length(local.azs))) :
    "${pair[0]}-${pair[1]}" => cidrsubnet(
      local.vpc_cidr,
      local.subnet_netmasks[pair[0]] - var.vpc_netmask_length,
      index(local.subnet_types, pair[0]) * length(local.azs) + pair[1]
    )
  }

  # Now group by type → list of CIDRs per AZ
  subnet_cidrs = {
    for type in local.subnet_types :
    type => [
      for az_index in range(length(local.azs)) :
      local.flat_subnets["${type}-${az_index}"]
    ]
  }
}

# Subnet CIDR allocations
# resource "aws_vpc_ipam_pool_cidr_allocation" "subnets" {
#   depends_on = [module.ipam]
#   for_each = {
#     for pair in setproduct(["transit", "private", "endpoints"], range(length(var.availability_zones))) :
#     "${pair[0]}-${pair[1]}" => {
#       type = pair[0]
#       index = pair[1]
#     }
#   }

#   ipam_pool_id   = local.ipam_pool_id
#   netmask_length = 26
# }

# Core VPC Module
module "core_vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.network-services
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 7

  # CloudWAN Configuration - module creates attachment with policy wait
  cloudwan_config = {
    enabled                 = true
    core_network_id         = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id
    core_network_account_id = var.network_services_account_id
    segment                 = "sharedservices"
    wait_for_policy         = true  # Wait for CloudWAN policy propagation
    policy_wait_duration    = "30s" # Wait 30 seconds for policy
  }

  vpc_configuration = {
    name         = "${var.environment}-core-vpc"
    type         = "networking"
    category     = "core"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
    region       = var.region
    account_type = "network-core"
    environment  = var.environment

    subnet_configuration = {
      for type in local.subnet_types : type => {
        type               = type
        cidr_blocks        = local.subnet_cidrs[type]
        availability_zones = var.availability_zones
        route_table_config = {
          routes = type == "transit" ? [
            # Transit subnets - CloudWAN managed, no additional routes needed
            ] : type == "private" ? [
            # Private subnets - could add NAT gateway routes if needed
            # {
            #   destination = "0.0.0.0/0"
            #   target_type = "nat"
            #   target_id   = "nat-gateway-id"
            # }
            ] : [
            # Endpoints subnets - local traffic only
          ]
        }
      }
    }

    features = {
      enable_dns_hostnames = true
      enable_dns_support   = true
      enable_flow_logs     = true
      # flow_logs_config not needed - module creates resources internally
    }

    tags = var.tags
  }
}

# DNS Module
module "dns" {
  source = "../../modules/dns"

  providers = {
    aws = aws.network-services
  }

  depends_on = [module.core_vpc]

  vpc_id     = module.core_vpc.vpc_id
  subnet_ids = module.core_vpc.subnets["private"]

  resolver_config = {
    inbound = {
      enabled = true
      ip_addresses = [
        for idx in range(length(var.availability_zones)) : {
          subnet_id = module.core_vpc.subnets["private"][var.availability_zones[idx]]
          ip        = cidrhost(local.subnet_cidrs["private"][idx], 10)
        }
      ]
    }
    outbound = {
      enabled = true
      ip_addresses = [
        for idx in range(length(var.availability_zones)) : {
          subnet_id = module.core_vpc.subnets["private"][var.availability_zones[idx]]
          ip        = cidrhost(local.subnet_cidrs["private"][idx], 20)
        }
      ]
      rules = var.resolver_config.outbound.rules
    }
  }

  private_hosted_zones  = var.private_hosted_zones
  external_hosted_zones = var.external_hosted_zones
  tags                  = var.tags
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  provider = aws.network-services

  name_prefix = "${var.environment}-vpc-endpoints-"
  vpc_id      = module.core_vpc.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.core_vpc.vpc_cidr]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [module.core_vpc.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-vpc-endpoints-sg"
  })
}

# VPC Endpoints Module
module "endpoints" {
  source = "../../modules/endpoints"

  providers = {
    aws = aws.network-services
  }

  region            = var.region
  vpc_id            = module.core_vpc.vpc_id
  subnet_ids        = module.core_vpc.subnets["endpoints"]
  route_table_ids   = values(module.core_vpc.route_tables)
  endpoint_services = var.endpoint_services
  security_group_id = aws_security_group.vpc_endpoints.id
  tags              = var.tags

  depends_on = [module.core_vpc]
}

# DNS Module for Endpoint Resolution
module "endpoint_dns" {
  source = "../../modules/dns"

  providers = {
    aws = aws.network-services
  }

  depends_on = [module.core_vpc, module.endpoints]

  vpc_id     = module.core_vpc.vpc_id
  subnet_ids = module.core_vpc.subnets["private"]

  # Pass endpoint data to DNS module
  endpoint_dns_data = module.endpoints.endpoint_dns_data

  resolver_config = {
    inbound = {
      enabled = true
      ip_addresses = [
        for idx in range(length(var.availability_zones)) : {
          subnet_id = module.core_vpc.subnets["private"][var.availability_zones[idx]]
          ip        = cidrhost(local.subnet_cidrs["private"][idx], 30)
        }
      ]
    }
    outbound = {
      enabled      = false
      ip_addresses = []
      rules        = []
    }
  }

  # Create private hosted zones for custom domains (not AWS services)
  # Note: AWS VPC endpoints automatically handle DNS resolution for amazonaws.com
  # We don't need to create private hosted zones for AWS service domains
  private_hosted_zones = [
    # Add custom private hosted zones here if needed
    # Example:
    # {
    #   name = "internal.company.com"
    #   comment = "Private hosted zone for internal services"
    # }
  ]

  # DNS records will be created automatically by DNS module using endpoint_dns_data

  enable_ram_sharing = true
  tags = merge(var.tags, {
    Purpose = "endpoint-dns-resolution"
  })
}

# Cross-account IAM role for network resource access
resource "aws_iam_role" "network_core_read" {
  provider = aws.network-services
  count    = var.is_primary_region ? 1 : 0
  name     = "NetworkCoreReadRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.management_account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:PrincipalOrgID" = data.aws_organizations_organization.current.id
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = "NetworkCoreReadRole"
    Purpose   = "Cross-account access to network resources"
    ManagedBy = "AFT-NetworkCore"
  })
}

# Policy for reading network resources
resource "aws_iam_role_policy" "network_read_policy" {
  provider = aws.network-services
  count    = var.is_primary_region ? 1 : 0
  name     = "NetworkCoreReadPolicy"
  role     = aws_iam_role.network_core_read[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcIpamPools",
          "ec2:GetIpamPool",
          "ec2:DescribeIpams"
        ]
        Resource = [
          "arn:aws:ec2:*:${var.network_services_account_id}:ipam/*",
          "arn:aws:ec2:*:${var.network_services_account_id}:ipam-pool/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "networkmanager:GetCoreNetwork",
          "networkmanager:DescribeCoreNetworks",
          "networkmanager:ListCoreNetworks"
        ]
        Resource = [
          "arn:aws:networkmanager::${var.network_services_account_id}:core-network/*"
        ]
      }
    ]
  })
}

# KMS Key for SSM Parameter Encryption
resource "aws_kms_key" "ssm_parameters" {
  provider                = aws.aft-management
  count                   = var.is_primary_region ? 1 : 0
  description             = "KMS key for encrypting SSM parameters"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.environment}-ssm-parameters-key"
  })
}

resource "aws_kms_alias" "ssm_parameters" {
  provider      = aws.aft-management
  count         = var.is_primary_region ? 1 : 0
  name          = "alias/${var.environment}-ssm-parameters"
  target_key_id = aws_kms_key.ssm_parameters[0].key_id
}

# Store network configuration in highly granular SSM parameters to avoid 4KB limit

# Core network ID only
resource "aws_ssm_parameter" "core_network_id" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/core/network-id"
  description = "CloudWAN Core Network ID"
  type        = "SecureString"
  value       = module.cloudwan[0].core_network_id
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Cross-account role ARN only
resource "aws_ssm_parameter" "cross_account_role" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/core/cross-account-role"
  description = "Cross-account role ARN for network access"
  type        = "SecureString"
  value       = aws_iam_role.network_core_read[0].arn
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Network core account ID only
resource "aws_ssm_parameter" "network_core_account_id" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/core/account-id"
  description = "Network core account ID"
  type        = "SecureString"
  value       = var.network_services_account_id
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Environment only
resource "aws_ssm_parameter" "environment" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/core/environment"
  description = "Environment name"
  type        = "SecureString"
  value       = var.environment
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Consolidated network core config that other modules expect
resource "aws_ssm_parameter" "network_core_config" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/config"
  description = "Network core configuration for other modules"
  type        = "SecureString"
  value = jsonencode({
    account_id             = var.network_services_account_id
    environment            = var.environment
    core_network_id        = module.cloudwan[0].core_network_id
    cross_account_role_arn = aws_iam_role.network_core_read[0].arn
    ipam_details = {
      ipam_id = module.ipam[0].ipam_details.ipam_id
      pools = {
        global = {
          id   = module.ipam[0].ipam_details.pools.core.id
          arn  = module.ipam[0].ipam_details.pools.core.arn
          cidr = module.ipam[0].ipam_details.pools.core.cidr
        }
      }
    }
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# IPAM ID only
resource "aws_ssm_parameter" "ipam_id" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/id"
  description = "IPAM ID"
  type        = "SecureString"
  value       = module.ipam[0].ipam_details.ipam_id
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Individual pool parameters (one per pool type)
resource "aws_ssm_parameter" "pool_core" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/pools/core"
  description = "Core IPAM pool details"
  type        = "SecureString"
  value = jsonencode({
    id   = module.ipam[0].ipam_details.pools.core.id
    arn  = module.ipam[0].ipam_details.pools.core.arn
    cidr = module.ipam[0].ipam_details.pools.core.cidr
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "pool_network" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/pools/network"
  description = "Network IPAM pool details"
  type        = "SecureString"
  value = jsonencode({
    id   = module.ipam[0].ipam_details.pools.network.id
    arn  = module.ipam[0].ipam_details.pools.network.arn
    cidr = module.ipam[0].ipam_details.pools.network.cidr
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "pool_workload" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/pools/workload"
  description = "Workload IPAM pool details"
  type        = "SecureString"
  value = jsonencode({
    id   = module.ipam[0].ipam_details.pools.workload.id
    arn  = module.ipam[0].ipam_details.pools.workload.arn
    cidr = module.ipam[0].ipam_details.pools.workload.cidr
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Regional pools - separate parameter per pool type per region
resource "aws_ssm_parameter" "regional_pools_core" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/regional-pools/core"
  description = "Core regional pool details"
  type        = "SecureString"
  value = jsonencode(
    try(module.ipam[0].ipam_details.pools.core.regional_pools, {})
  )
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "regional_pools_network" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/regional-pools/network"
  description = "Network regional pool details"
  type        = "SecureString"
  value = jsonencode(
    try(module.ipam[0].ipam_details.pools.network.regional_pools, {})
  )
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "regional_pools_workload" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/ipam/regional-pools/workload"
  description = "Workload regional pool details"
  type        = "SecureString"
  value = jsonencode(
    try(module.ipam[0].ipam_details.pools.workload.regional_pools, {})
  )
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Current region VPC CIDR only
resource "aws_ssm_parameter" "vpc_cidr" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/allocations/${var.region}/vpc-cidr"
  description = "VPC CIDR for ${var.region}"
  type        = "SecureString"
  value       = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
  key_id      = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

# Current region subnets - split by subnet type
resource "aws_ssm_parameter" "subnets_transit" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/allocations/${var.region}/subnets/transit"
  description = "Transit subnet CIDRs for ${var.region}"
  type        = "SecureString"
  value = jsonencode({
    for key, cidr in local.flat_subnets : key => cidr
    if startswith(key, "transit-")
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "subnets_private" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/allocations/${var.region}/subnets/private"
  description = "Private subnet CIDRs for ${var.region}"
  type        = "SecureString"
  value = jsonencode({
    for key, cidr in local.flat_subnets : key => cidr
    if startswith(key, "private-")
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

resource "aws_ssm_parameter" "subnets_endpoints" {
  provider = aws.aft-management
  count    = var.is_primary_region ? 1 : 0

  name        = "/aft/network/allocations/${var.region}/subnets/endpoints"
  description = "Endpoints subnet CIDRs for ${var.region}"
  type        = "SecureString"
  value = jsonencode({
    for key, cidr in local.flat_subnets : key => cidr
    if startswith(key, "endpoints-")
  })
  key_id = aws_kms_key.ssm_parameters[0].id

  tags = var.tags
}

