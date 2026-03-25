data "aws_region" "current" {
  provider = aws.security
}
data "aws_caller_identity" "current" {
  provider = aws.security
}

# Global IPAM pool lookup for CloudWAN routing - use static ranges
# data "aws_vpc_ipam_pool" "global" {
#   provider = aws.network-core
#   filter {
#     name   = "tag:Name"
#     values = ["${var.environment}-global-ipam-pool"]
#   }
# }

locals {
  name_prefix     = "${substr(var.environment, 0, 8)}-${substr(var.region, -1, 1)}${substr(var.region, -3, 1)}-insp" # e.g., "[ENVIRONMENT]-[REGION]-insp"
  ipam_pool_id    = data.aws_vpc_ipam_pool.inspection_regional.id
  core_network_id = data.aws_ssm_parameter.core_network_id.value

  # Security service configuration
  #enable_network_firewall = try(var.security_config.aws_network_firewall.enabled, false)

  # Use static CIDR ranges for CloudWAN routing (these should match your IPAM configuration)
  aws_cidr_ranges = [
    "10.0.0.0/8", # Your organization's main CIDR block
    "0.0.0.0/0"   # Default route for internet traffic → forward to Egress segment
  ]

  # Create CloudWAN routes for each global CIDR block (without sensitive values)
  cloudwan_routes = [
    for cidr in local.aws_cidr_ranges : {
      destination = cidr
      target_type = "cloudwan"
      target_id   = "cloudwan-core-network" # Placeholder - will be replaced by VPC module
    }
  ]

  # Dynamic subnet configuration from variables
  subnet_configuration = {
    for type, netmask in var.subnet_netmasks : type => {
      type           = type
      netmask_length = netmask
    }
  }

  # Route configuration map for different subnet types - OPTIMIZED
  route_configs = {
    inspection = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = false }
    management = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = false }                         # Route via CloudWAN
    transit    = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = false, cloudwan_egress = true } # Transit routes to CloudWAN for egress
    public     = { internet_gateway = false, gwlb_endpoint = false, nat_gateway = false }                         # No public subnets needed without NAT
  }

  # Extract netmasks for CIDR calculation
  subnet_netmasks = {
    for type, config in local.subnet_configuration : type => config.netmask_length
  }

  # Subnet types from subnet configuration - OPTIMIZED ORDER
  subnet_types_ordered = ["transit", "inspection", "public", "management"]
  subnet_types         = [for type in local.subnet_types_ordered : type if contains(keys(local.subnet_configuration), type)]

  # Validate subnet netmasks against VPC size
  _validate_subnets = {
    for type, netmask in var.subnet_netmasks :
    type => netmask >= var.vpc_netmask_length ? netmask :
    error("Subnet ${type} netmask (${netmask}) must be >= VPC netmask (${var.vpc_netmask_length})")
  }
}

# IPAM Allocations
resource "aws_vpc_ipam_pool_cidr_allocation" "vpc" {
  provider       = aws.security
  ipam_pool_id   = local.ipam_pool_id
  netmask_length = var.vpc_netmask_length
}

locals {
  azs      = var.availability_zones
  vpc_cidr = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr

  # CIDR calculation with configurable netmasks - FIXED ORDER with proper spacing
  flat_subnets = {
    for pair in setproduct(local.subnet_types, range(length(local.azs))) :
    "${pair[0]}-${pair[1]}" => cidrsubnet(
      local.vpc_cidr,
      local.subnet_netmasks[pair[0]] - var.vpc_netmask_length,
      # Calculate index with proper spacing to avoid conflicts
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

# Inspection VPC Module
module "inspection_vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.security
  }

  is_primary_region = var.is_primary_region

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 30

  # CloudWAN Configuration - module creates attachment
  cloudwan_config = {
    enabled                 = true
    core_network_id         = local.core_network_id
    core_network_account_id = var.network_core_account_id
    segment                 = "inspection"
    attachment_tags = {
      nfg          = "inspection"
      account-type = "security-inspection"
      approved-by  = "security-team"
    }
  }

  # CloudWAN Routes - Always create routes, firewall module will add firewall-specific routes
  cloudwan_routes = {
    inspection = ["10.0.0.0/8", "0.0.0.0/0"]
    management = ["10.0.0.0/8"]
  }

  vpc_configuration = {
    name         = "${var.environment}-inspection-vpc"
    type         = "inspection"
    category     = "security"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
    region       = var.region
    account_type = "network-inspection"
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
              target_id   = "local"
            }
            ],
            # Internet Gateway route (conditional for public subnets)
            local.route_configs[type].internet_gateway ? [{
              destination = "0.0.0.0/0"
              target_type = "internet_gateway"
              target_id   = "igw-placeholder" # Will be replaced by VPC module
            }] : [],
            # NAT Gateway route (conditional for management subnets) - CRITICAL FOR EGRESS
            local.route_configs[type].nat_gateway ? [{
              destination = "0.0.0.0/0"
              target_type = "nat_gateway"
              target_id   = "nat-placeholder" # Will be replaced by VPC module
            }] : [],
            # CloudWAN routes (always present)
          local.cloudwan_routes)
        }
      }
    }

    features = {
      enable_dns_hostnames    = true
      enable_dns_support      = true
      enable_flow_logs        = true  # Enable flow logs (module creates resources)
      enable_nat_gateway      = false # DISABLED - Force traffic through CloudWAN to Egress VPC
      enable_internet_gateway = false # DISABLED - No local internet egress
      create_igw              = false # DISABLED - No IGW needed
      # DNS resolution via network-core resolvers
      dhcp_options_domain_name_servers = [
        "network-core-resolver-1",
        "network-core-resolver-2"
      ]
    }
    tags = var.tags
  }
}

# KMS key for SSM parameter encryption (CKV_AWS_337)
resource "aws_kms_key" "ssm_parameters" {
  provider                = aws.security
  description             = "KMS key for SSM parameter encryption in inspection VPC"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ssm-parameters"
  })
}

resource "aws_kms_alias" "ssm_parameters" {
  provider      = aws.security
  name          = "alias/${var.environment}-inspection-ssm-parameters"
  target_key_id = aws_kms_key.ssm_parameters.key_id
}

# Store inspection details in SSM Parameter Store
resource "aws_ssm_parameter" "inspection_config" {
  provider = aws.security

  name        = "/aft/network/inspection/config"
  description = "Inspection VPC configuration"
  type        = "SecureString"
  key_id      = aws_kms_key.ssm_parameters.id
  value = jsonencode({
    vpc_details = {
      vpc_id   = module.inspection_vpc.vpc_id
      vpc_cidr = local.vpc_cidr
      subnets  = module.inspection_vpc.subnets
    }
    security_services = {
      gwlb = var.security_config.gwlb.enabled ? {
        gwlb_arn              = module.gwlb[0].gwlb_arn
        gwlb_endpoint_service = module.gwlb[0].gwlb_endpoint_service_name
        gwlb_endpoint_ids     = module.gwlb[0].gwlb_endpoint_ids
        target_group_arn      = module.gwlb[0].target_group_arn
        router_asg_name       = module.gwlb[0].autoscaling_group_name
      } : null
    }
    environment  = var.environment
    optimization = "simple-linux-routers"
  })

  tags = var.tags

  depends_on = [module.gwlb]
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  provider    = aws.security
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}