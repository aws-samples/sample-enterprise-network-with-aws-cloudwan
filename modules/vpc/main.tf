# IPAM Pool CIDR Allocation (if enabled)
resource "aws_vpc_ipam_pool_cidr_allocation" "vpc" {
  count          = var.ipam_allocation.enabled ? 1 : 0
  ipam_pool_id   = var.ipam_allocation.ipam_pool_id
  netmask_length = var.ipam_allocation.netmask_length
}

locals {
  # Use IPAM-allocated CIDR if enabled, otherwise use provided cidr_block
  vpc_cidr = var.ipam_allocation.enabled ? aws_vpc_ipam_pool_cidr_allocation.vpc[0].cidr : var.vpc_configuration.cidr_block
}

# VPC with IPAM
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = var.vpc_configuration.features.enable_dns_hostnames
  enable_dns_support   = var.vpc_configuration.features.enable_dns_support

  tags = local.vpc_tags
}

# Manage default security group - remove all rules for security
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # Remove all ingress rules
  ingress = []

  # Remove all egress rules  
  egress = []

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-default-sg-managed"
  })
}

locals {
  # Default domain name based on region if not provided
  default_domain_name = var.vpc_configuration.region == "us-east-1" ? "ec2.internal" : "${var.vpc_configuration.region}.compute.internal"

  # Check if DHCP options are enabled (default to true if not specified)
  dhcp_options_enabled = try(var.vpc_configuration.features.dhcp_options.enabled, true)

  # Get domain name (use default if not provided)
  domain_name = try(var.vpc_configuration.features.dhcp_options.domain_name, local.default_domain_name)
}

resource "aws_vpc_dhcp_options" "main" {
  count = local.dhcp_options_enabled ? 1 : 0

  domain_name         = local.domain_name
  domain_name_servers = try(var.vpc_configuration.features.dhcp_options.domain_name_servers, ["AmazonProvidedDNS"])

  # Only include these if they're provided
  ntp_servers          = try(var.vpc_configuration.features.dhcp_options.ntp_servers, null)
  netbios_name_servers = try(var.vpc_configuration.features.dhcp_options.netbios_name_servers, null)
  netbios_node_type    = try(var.vpc_configuration.features.dhcp_options.netbios_node_type, null)

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-dhcp-options"
  })
}

resource "aws_vpc_dhcp_options_association" "main" {
  count = local.dhcp_options_enabled ? 1 : 0

  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main[0].id
}

# VPC Flow Logs Resources
# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? 1 : 0

  name              = "/aws/vpc/flowlogs/${var.vpc_configuration.name}"
  retention_in_days = var.flow_log_retention_days

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-flow-logs"
  })
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? 1 : 0

  name = var.flow_log_role_name != null ? var.flow_log_role_name : "${local.name_prefix}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-flow-logs-role"
  })
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? 1 : 0

  name = "${local.name_prefix}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
      }
    ]
  })
}

# Flow Logs - use module-created resources or external resources
resource "aws_flow_log" "main" {
  count = var.vpc_configuration.features.enable_flow_logs ? 1 : 0

  # Use module-created resources if available, otherwise use provided ARNs
  log_destination      = var.create_flow_log_resources ? aws_cloudwatch_log_group.flow_logs[0].arn : var.vpc_configuration.features.flow_logs_config.log_group_arn
  log_destination_type = "cloud-watch-logs"
  iam_role_arn         = var.create_flow_log_resources ? aws_iam_role.flow_logs[0].arn : var.vpc_configuration.features.flow_logs_config.iam_role_arn

  vpc_id       = aws_vpc.main.id
  traffic_type = var.create_flow_log_resources ? "ALL" : var.vpc_configuration.features.flow_logs_config.traffic_type

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-flow-logs"
  })
}

# Internet Gateway (if enabled)
resource "aws_internet_gateway" "main" {
  count  = var.vpc_configuration.features.create_igw ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# NAT Gateway resources
# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.vpc_configuration.features.enable_nat_gateway ? 3 : 0

  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# Local to find public subnets for NAT gateway placement
locals {
  public_subnet_ids = var.vpc_configuration.features.enable_nat_gateway ? [
    for k, v in aws_subnet.subnets : v.id
    if contains(split("-", k), "public")
  ] : []
}

# NAT Gateways - placed in public subnets
resource "aws_nat_gateway" "main" {
  count = var.vpc_configuration.features.enable_nat_gateway ? min(3, length(local.public_subnet_ids)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = local.public_subnet_ids[count.index]

  depends_on = [aws_internet_gateway.main, aws_subnet.subnets]

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-nat-gateway-${count.index + 1}"
  })
}

# Wait for CloudWAN policy propagation (if needed - typically for network-core)
resource "time_sleep" "wait_for_policy" {
  count = var.cloudwan_config.enabled && var.cloudwan_config.wait_for_policy ? 1 : 0

  create_duration = var.cloudwan_config.policy_wait_duration
}

# CloudWAN VPC Attachment
resource "aws_networkmanager_vpc_attachment" "main" {
  count = var.cloudwan_config.enabled ? 1 : 0

  depends_on = [
    time_sleep.wait_for_policy
  ]

  core_network_id = var.cloudwan_config.core_network_id
  vpc_arn         = aws_vpc.main.arn

  # Use transit subnets for CloudWAN attachment
  subnet_arns = [
    for subnet_key, subnet in aws_subnet.subnets :
    "arn:aws:ec2:${var.vpc_configuration.region}:${data.aws_caller_identity.current.account_id}:subnet/${subnet.id}"
    if startswith(subnet_key, "transit-")
  ]

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      tags["attachment-state"]
    ]
  }

  tags = merge(local.vpc_tags, var.cloudwan_config.attachment_tags, {
    Name        = "${var.vpc_configuration.environment}-${var.vpc_configuration.type}-vpc-attachment"
    segment     = var.cloudwan_config.segment
    environment = var.vpc_configuration.environment
  })
}

# RAM Resource Share (for subnet sharing)
resource "aws_ram_resource_share" "vpc" {
  count = var.ram_sharing_config.enabled ? 1 : 0

  name                      = var.ram_sharing_config.share_name != null ? var.ram_sharing_config.share_name : "${local.name_prefix}-subnet-share"
  allow_external_principals = false

  tags = merge(local.vpc_tags, {
    Name    = "${local.name_prefix}-subnet-share"
    Purpose = "subnet-sharing"
  })
}

# RAM Principal Associations - Accounts
resource "aws_ram_principal_association" "accounts" {
  count = var.ram_sharing_config.enabled ? length(var.ram_sharing_config.share_with_accounts) : 0

  principal          = var.ram_sharing_config.share_with_accounts[count.index]
  resource_share_arn = aws_ram_resource_share.vpc[0].arn
}

# RAM Principal Association - Organization
resource "aws_ram_principal_association" "organization" {
  count = var.ram_sharing_config.enabled && var.ram_sharing_config.share_with_org && var.ram_sharing_config.organization_id != null ? 1 : 0

  principal          = var.ram_sharing_config.organization_id
  resource_share_arn = aws_ram_resource_share.vpc[0].arn
}

# RAM Resource Association - Subnets (VPCs cannot be shared, only subnets)
resource "aws_ram_resource_association" "subnets" {
  for_each = var.ram_sharing_config.enabled ? local.all_subnets : {}

  resource_arn       = "arn:aws:ec2:${var.vpc_configuration.region}:${data.aws_caller_identity.current.account_id}:subnet/${each.value}"
  resource_share_arn = aws_ram_resource_share.vpc[0].arn
}

# Local to get all subnet IDs for sharing
locals {
  all_subnets = var.ram_sharing_config.enabled ? {
    for subnet_key, subnet in aws_subnet.subnets : subnet_key => subnet.id
  } : {}
}

# Data source for current account ID
data "aws_caller_identity" "current" {}