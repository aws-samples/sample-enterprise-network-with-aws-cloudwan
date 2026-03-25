
locals {
  # Base pools to share (parent pools)
  base_pools_to_share = {
    "core"     = aws_vpc_ipam_pool.core.arn
    "network"  = aws_vpc_ipam_pool.network.arn
    "workload" = aws_vpc_ipam_pool.workload.arn
  }

  # Regional pools to share
  regional_core_pools = {
    for region, pool in aws_vpc_ipam_pool.core_regional :
    "core-${region}" => pool.arn
  }

  regional_network_pools = {
    for region, pool in aws_vpc_ipam_pool.network_regional :
    "network-${region}" => pool.arn
  }

  regional_workload_pools = {
    for region, pool in aws_vpc_ipam_pool.workload_regional :
    "workload-${region}" => pool.arn
  }

  # Combine all pools to share
  shared_pool_arns = merge(
    local.base_pools_to_share,
    local.regional_core_pools,
    local.regional_network_pools,
    local.regional_workload_pools
  )
}

# RAM Resource Share
resource "aws_ram_resource_share" "ipam_pools" {
  count = var.enable_ram_sharing ? 1 : 0

  name                      = "${var.environment}-ipam-pools-share"
  allow_external_principals = false

  tags = merge(var.tags, {
    Name = "${var.environment}-ipam-pools-share"
  })
}

# RAM Resource Association
resource "aws_ram_resource_association" "ipam_pools" {
  for_each = var.enable_ram_sharing ? local.shared_pool_arns : {}

  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.ipam_pools[0].arn
}

# RAM Principal Association (with Organization)
resource "aws_ram_principal_association" "org_sharing" {
  count = var.enable_ram_sharing ? 1 : 0

  principal          = data.aws_organizations_organization.current.arn
  resource_share_arn = aws_ram_resource_share.ipam_pools[0].arn
}
