data "aws_availability_zones" "available" {
  provider = aws.security
  state    = "available"
}

data "aws_vpc_ipam_pool" "inspection_regional" {
  provider = aws.network-core
  filter {
    name   = "tag:Name"
    values = ["network-${var.region}-ipam-pool"]
  }
}

# Get core network ID from SSM parameter (stored by network-core module)
data "aws_ssm_parameter" "core_network_id" {
  provider = aws.network-core
  name     = "/aft/network/core/network-id"
}

# Global IPAM pool lookup for CloudWAN routing - use static CIDR ranges instead
# data "aws_vpc_ipam_pool" "global" {
#   provider = aws.network-core
#   filter {
#     name   = "tag:Name"
#     values = ["${var.environment}-global-ipam-pool"]
#   }
# }