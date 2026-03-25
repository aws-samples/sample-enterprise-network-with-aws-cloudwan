# AWS Network Firewall for Egress VPC
# Purpose: Inspect all internet-bound traffic before NAT Gateway
# Updated based on AWS Support recommendations:
# - Removed allow-all rule at IP level (causes all traffic to match at lower layer)
# - Added explicit allow rules for required domains
# - Enabled drop_established action for better control

# Enable/disable Network Firewall
locals {
  enable_network_firewall = true  # Set to false to destroy firewall
  enable_test_block_rules = false # Disabled - using explicit allow rules instead
}

# Allowed domains for internet access
locals {
  allowed_domains = [
    "google.com",
    ".google.com",
    ".googleapis.com",
    "github.com",
    ".github.com",
    ".githubusercontent.com",
    "terraform.io",
    ".terraform.io",
    "hashicorp.com",
    ".hashicorp.com",
    ".registry.terraform.io",
    ".releases.hashicorp.com",
    "amazon.com",
    ".amazon.com",
    "amazonaws.com",
    ".amazonaws.com"
  ]

  # Blocked domains for testing (optional)
  blocked_domains = [
    "facebook.com",
    ".facebook.com",
    "twitter.com",
    ".twitter.com",
    "instagram.com",
    ".instagram.com"
  ]
}

# Deploy Network Firewall using reusable module
module "network_firewall" {
  count  = local.enable_network_firewall ? 1 : 0
  source = "../../modules/network-firewall"

  providers = {
    aws = aws.network-services
  }

  name_prefix              = local.name_prefix
  vpc_id                   = module.egress_vpc.vpc_id
  subnet_ids               = values(module.egress_vpc.subnets["firewall"])
  log_retention_days       = 30
  rule_order               = "STRICT_ORDER"
  enable_test_block_rules  = local.enable_test_block_rules
  enable_drop_established  = true  # Enable to block non-matching traffic (whitelist mode)
  enable_alert_established = false # DISABLED - when combined with drop_established, it prevents dropping
  # Note: ALERT_ALL is not supported via Terraform - must be enabled manually in AWS Console
  # With drop_established ONLY: blocked domains (priority 5) -> allowed domains (priority 100) -> drop all others
  # This creates a proper whitelist: only explicitly allowed domains can access internet
  allowed_domains = local.allowed_domains
  blocked_domains = local.blocked_domains # Explicit block list with alerts

  # Route Management - Module handles all firewall routes
  manage_routes = true
  route_table_ids = {
    transit  = module.egress_vpc.route_table_ids["transit"]
    firewall = module.egress_vpc.route_table_ids["firewall"]
    public   = module.egress_vpc.route_table_ids["public"]
  }

  # Transit subnet routes (from CloudWAN → Firewall)
  transit_routes = [
    {
      destination_cidr_block = "0.0.0.0/0"
      description            = "Route internet traffic through firewall"
    },
    {
      destination_cidr_block = "10.0.0.0/8"
      description            = "Route internal traffic through firewall"
    }
  ]

  # Firewall subnet routes (after inspection)
  firewall_routes = [
    {
      destination_cidr_block = "10.0.0.0/8"
      target_type            = "cloudwan"
      description            = "Route return traffic to CloudWAN"
    }
  ]

  # Public subnet return routes (asymmetric routing fix)
  public_return_routes = [
    {
      destination_cidr_block = "10.0.0.0/8"
      description            = "Return traffic through firewall"
    },
    {
      destination_cidr_block = "10.72.0.0/24"
      description            = "Application VPC return traffic"
    },
    {
      destination_cidr_block = "10.72.1.0/24"
      description            = "Development VPC return traffic"
    }
  ]

  core_network_arn = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${local.core_network_id}"

  tags = merge(var.tags, {
    Purpose = "internet-egress-inspection"
    VPC     = "egress"
  })

  depends_on = [module.egress_vpc]
}

# Routes are now managed by the network_firewall module
# No need for standalone route resources

# Store Network Firewall endpoint IDs in SSM for reference
resource "aws_ssm_parameter" "firewall_endpoints" {
  count    = local.enable_network_firewall ? 1 : 0
  provider = aws.network-services

  name        = "/aft/network/egress/firewall-endpoints"
  description = "Network Firewall endpoint IDs for Egress VPC"
  type        = "String"
  value       = jsonencode(module.network_firewall[0].firewall_endpoint_ids)

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
  description = "Network Firewall endpoint IDs"
  value       = local.enable_network_firewall ? module.network_firewall[0].firewall_endpoint_ids : []
}

output "network_firewall_log_group" {
  description = "CloudWatch log group for Network Firewall logs"
  value       = local.enable_network_firewall ? module.network_firewall[0].log_group_name : null
}
