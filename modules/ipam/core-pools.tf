# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Core Pool (directly under Global)
resource "aws_vpc_ipam_pool" "core" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Core IPAM pool for infrastructure resources"
  source_ipam_pool_id = aws_vpc_ipam_pool.global.id
  locale              = "None"
  auto_import         = false

  tags = merge(var.tags, {
    Name = "${var.environment}-core-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.global]
}

resource "aws_vpc_ipam_pool_cidr" "core" {
  ipam_pool_id = aws_vpc_ipam_pool.core.id
  cidr         = var.pool_configuration.pool_cidrs.core_cidr
  depends_on   = [aws_vpc_ipam_pool_cidr.global, aws_vpc_ipam_pool.core]
}

# Core Regional Pools
resource "aws_vpc_ipam_pool" "core_regional" {
  for_each = var.regional_config

  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Core IPAM pool for ${each.key} region"
  source_ipam_pool_id = aws_vpc_ipam_pool.core.id
  locale              = each.key
  auto_import         = false # Use explicit CIDR management

  tags = merge(var.tags, {
    Name = "core-${each.key}-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.core]
}

# Explicit CIDR allocation TO regional pools from parent pools
resource "aws_vpc_ipam_pool_cidr" "core_regional" {
  for_each = var.regional_config

  ipam_pool_id = aws_vpc_ipam_pool.core_regional[each.key].id
  cidr         = cidrsubnet(var.pool_configuration.pool_cidrs.core_cidr, 8, index(keys(var.regional_config), each.key))
  depends_on   = [aws_vpc_ipam_pool.core_regional, aws_vpc_ipam_pool_cidr.core]
}

# Network Pool (directly under Global)
resource "aws_vpc_ipam_pool" "network" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Network IPAM pool for transit and networking resources"
  source_ipam_pool_id = aws_vpc_ipam_pool.global.id
  locale              = "None"
  auto_import         = false

  tags = merge(var.tags, {
    Name = "${var.environment}-network-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.global]
}

resource "aws_vpc_ipam_pool_cidr" "network" {
  ipam_pool_id = aws_vpc_ipam_pool.network.id
  cidr         = var.pool_configuration.pool_cidrs.network_cidr
  depends_on   = [aws_vpc_ipam_pool_cidr.global, aws_vpc_ipam_pool.network]
}

# Network Regional Pools
resource "aws_vpc_ipam_pool" "network_regional" {
  for_each = var.regional_config

  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Network IPAM pool for ${each.key} region"
  source_ipam_pool_id = aws_vpc_ipam_pool.network.id
  locale              = each.key
  auto_import         = false # Use explicit CIDR management

  tags = merge(var.tags, {
    Name = "network-${each.key}-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.network]
}

# Explicit CIDR allocation TO regional pools from parent pools
resource "aws_vpc_ipam_pool_cidr" "network_regional" {
  for_each = var.regional_config

  ipam_pool_id = aws_vpc_ipam_pool.network_regional[each.key].id
  cidr         = cidrsubnet(var.pool_configuration.pool_cidrs.network_cidr, 2, index(keys(var.regional_config), each.key))
  depends_on   = [aws_vpc_ipam_pool.network_regional, aws_vpc_ipam_pool_cidr.network]
}

# Workload Pool (directly under Global)
resource "aws_vpc_ipam_pool" "workload" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Workload IPAM pool for application resources"
  source_ipam_pool_id = aws_vpc_ipam_pool.global.id
  locale              = "None"
  auto_import         = false

  tags = merge(var.tags, {
    Name = "${var.environment}-workload-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.global]
}

resource "aws_vpc_ipam_pool_cidr" "workload" {
  ipam_pool_id = aws_vpc_ipam_pool.workload.id
  cidr         = var.pool_configuration.pool_cidrs.workload_cidr
  depends_on   = [aws_vpc_ipam_pool_cidr.global, aws_vpc_ipam_pool.workload]
}

# Workload Regional Pools
resource "aws_vpc_ipam_pool" "workload_regional" {
  for_each = var.regional_config

  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam_scope.private.id
  description         = "Workload IPAM pool for ${each.key} region"
  source_ipam_pool_id = aws_vpc_ipam_pool.workload.id
  locale              = each.key
  auto_import         = false # Use explicit CIDR management

  tags = merge(var.tags, {
    Name = "workload-${each.key}-ipam-pool"
  })
  depends_on = [aws_vpc_ipam_pool_cidr.workload]
}

# Explicit CIDR allocation TO regional pools from parent pools
resource "aws_vpc_ipam_pool_cidr" "workload_regional" {
  for_each = var.regional_config

  ipam_pool_id = aws_vpc_ipam_pool.workload_regional[each.key].id
  cidr         = cidrsubnet(var.pool_configuration.pool_cidrs.workload_cidr, 2, index(keys(var.regional_config), each.key))
  depends_on   = [aws_vpc_ipam_pool.workload_regional, aws_vpc_ipam_pool_cidr.workload]
}