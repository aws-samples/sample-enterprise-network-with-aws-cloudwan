# main.tf
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {
  provider = aws.org-management
}

# Main IPAM
resource "aws_vpc_ipam" "main" {
  description = "IPAM with primary in ${var.primary_region}"
  operating_regions {
    region_name = var.primary_region
  }

  dynamic "operating_regions" {
    for_each = toset([for region in var.enabled_regions : region if region != var.primary_region])
    content {
      region_name = operating_regions.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-ipam"
  })
}

# Public Scope
resource "aws_vpc_ipam_scope" "public" {
  ipam_id     = aws_vpc_ipam.main.id
  description = "Public IPAM scope"
  tags = merge(var.tags, {
    Name = "${var.environment}-public-scope"
  })
}

# Private Scope
resource "aws_vpc_ipam_scope" "private" {
  ipam_id     = aws_vpc_ipam.main.id
  description = "Private IPAM scope"
  tags = merge(var.tags, {
    Name = "${var.environment}-private-scope"
  })
}

# Global Pool (Top Level)
# main.tf
resource "aws_vpc_ipam_pool" "global" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam_scope.private.id
  description    = "Global AWS IPAM Pool"

  allocation_default_netmask_length = 16
  tags = merge(var.tags, {
    Name = "${var.environment}-global-ipam-pool"
  })
}

# Wait for IPAM to be fully ready before creating pool CIDRs
resource "time_sleep" "wait_for_ipam" {
  depends_on      = [aws_vpc_ipam_pool.global]
  create_duration = "30s"
}

resource "aws_vpc_ipam_pool_cidr" "global" {
  ipam_pool_id = aws_vpc_ipam_pool.global.id
  cidr         = var.pool_configuration.pool_cidrs.global_cidr
  depends_on   = [time_sleep.wait_for_ipam]
}