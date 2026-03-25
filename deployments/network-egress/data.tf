data "aws_availability_zones" "available" {
  provider = aws.network-services
  state    = "available"
}

data "aws_vpc_ipam_pool" "egress" {
  provider = aws.network-services

  filter {
    name   = "tag:Name"
    values = ["network-${var.region}-ipam-pool"]
  }
}

# Get core network ID from SSM parameter (stored by network-core module)
data "aws_ssm_parameter" "core_network_id" {
  provider = aws.network-services
  name     = "/aft/network/core/network-id"
}