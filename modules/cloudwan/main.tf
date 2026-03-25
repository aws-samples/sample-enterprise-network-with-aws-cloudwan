terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.7.0"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Module      = "cloudwan"
  })

  resource_prefix = var.resource_prefix != null ? var.resource_prefix : "${var.environment}"
}

resource "aws_networkmanager_global_network" "main" {
  description = var.global_network_description != null ? var.global_network_description : "Global Network"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-global-network"
  })
}

resource "aws_networkmanager_core_network" "main" {
  global_network_id = aws_networkmanager_global_network.main.id
  description       = var.core_network_description != null ? var.core_network_description : "Core Network"

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-core-network"
  })
}

# RAM Resource Share for CloudWAN (Primary Region Only)
resource "aws_ram_resource_share" "cloudwan" {
  count = var.is_primary_region && var.enable_ram_sharing ? 1 : 0

  name                      = "${local.resource_prefix}-cloudwan-share"
  allow_external_principals = false

  tags = merge(local.common_tags, {
    Name = "${local.resource_prefix}-cloudwan-share"
  })
}

# Associate Core Network with RAM Share
resource "aws_ram_resource_association" "core_network" {
  count = var.is_primary_region && var.enable_ram_sharing ? 1 : 0

  resource_arn       = aws_networkmanager_core_network.main.arn
  resource_share_arn = aws_ram_resource_share.cloudwan[0].arn
}

# Share with Organization
resource "aws_ram_principal_association" "organization" {
  count = var.is_primary_region && var.enable_ram_sharing && var.organization_id != null ? 1 : 0

  principal          = var.organization_id
  resource_share_arn = aws_ram_resource_share.cloudwan[0].arn
}

# Share with specific accounts
resource "aws_ram_principal_association" "accounts" {
  count = var.is_primary_region && var.enable_ram_sharing ? length(var.share_with_accounts) : 0

  principal          = var.share_with_accounts[count.index]
  resource_share_arn = aws_ram_resource_share.cloudwan[0].arn
}

# VPC Attachments (for Network Services Account)
resource "aws_networkmanager_vpc_attachment" "network_services" {
  for_each = var.vpc_attachments

  core_network_id = aws_networkmanager_core_network.main.id
  vpc_arn         = each.value.vpc_arn
  subnet_arns     = each.value.subnet_arns

  tags = merge(local.common_tags, {
    Name    = "${each.key}-vpc-attachment"
    segment = each.value.segment
  })

  # Ensure policy is processed before creating attachments
  depends_on = [time_sleep.wait_for_policy]
}