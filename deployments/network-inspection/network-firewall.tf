# AWS Network Firewall for Inspection VPC
# Purpose: Inspect east-west traffic between segments

# Enable/disable Network Firewall
locals {
  enable_network_firewall = try(var.security_config.aws_network_firewall.enabled, false)
}

# Deploy Network Firewall using reusable module with custom blocking rules
module "network_firewall" {
  count  = local.enable_network_firewall ? 1 : 0
  source = "../../modules/network-firewall"

  providers = {
    aws = aws.security
  }

  name_prefix              = local.name_prefix
  vpc_id                   = module.inspection_vpc.vpc_id
  subnet_ids               = values(module.inspection_vpc.subnets["inspection"])
  log_retention_days       = 30
  rule_order               = "STRICT_ORDER" # Use STRICT_ORDER for explicit rule priority
  enable_test_block_rules  = false
  enable_drop_established  = false # Don't drop non-matching traffic (allow by default)
  enable_alert_established = false # Don't alert on established connections

  # Custom blocking rules: Block specific IPs and traffic patterns
  custom_block_rules = [
    {
      name        = "block-dev-to-prod-ip"
      source      = "10.72.1.0/24"
      destination = "10.72.0.8/32"
      description = "Block Development VPC (entire subnet) traffic to Production IP 10.72.0.8"
    }
  ]

  # Route Management - Module handles all firewall routes
  manage_routes = true
  route_table_ids = {
    transit    = module.inspection_vpc.route_table_ids["transit"]
    inspection = module.inspection_vpc.route_table_ids["inspection"]
  }

  # Transit subnet routes (from CloudWAN → Firewall)
  transit_routes = [
    {
      destination_cidr_block = "0.0.0.0/0"
      description            = "Route all traffic through firewall"
    },
    {
      destination_cidr_block = "10.0.0.0/8"
      description            = "Route internal traffic through firewall"
    }
  ]

  # Inspection subnet routes (after inspection → CloudWAN)
  firewall_routes = [
    {
      destination_cidr_block = "10.0.0.0/8"
      target_type            = "cloudwan"
      description            = "Route inspected traffic to CloudWAN"
    },
    {
      destination_cidr_block = "0.0.0.0/0"
      target_type            = "cloudwan"
      description            = "Route default traffic to CloudWAN"
    }
  ]

  core_network_arn = "arn:aws:networkmanager::${var.network_core_account_id}:core-network/${local.core_network_id}"

  tags = merge(var.tags, {
    Purpose = "east-west-inspection"
    VPC     = "inspection"
  })

  depends_on = [module.inspection_vpc]
}

# Routes are now managed by the network_firewall module
# No need for standalone route resources

# Extract firewall endpoints for reference
locals {
  firewall_endpoints = local.enable_network_firewall ? module.network_firewall[0].firewall_endpoints : {}
}

# Store Network Firewall endpoint IDs in SSM for reference
resource "aws_ssm_parameter" "firewall_endpoints" {
  count    = local.enable_network_firewall ? 1 : 0
  provider = aws.security

  name        = "/aft/network/inspection/firewall-endpoints"
  description = "Network Firewall endpoint IDs for Inspection VPC"
  type        = "String"
  value       = jsonencode(local.firewall_endpoints)

  tags = var.tags
}

# Output Network Firewall details
output "network_firewall_id" {
  description = "Network Firewall ID"
  value       = local.enable_network_firewall ? module.network_firewall[0].firewall_id : null
}

output "network_firewall_arn" {
  description = "Network Firewall ARN"
  value       = local.enable_network_firewall ? module.network_firewall[0].firewall_arn : null
}

output "network_firewall_endpoints" {
  description = "Network Firewall endpoint IDs by AZ"
  value       = local.firewall_endpoints
}

output "network_firewall_log_group" {
  description = "CloudWatch log group for Network Firewall logs"
  value       = local.enable_network_firewall ? module.network_firewall[0].log_group_name : null
}