### secoperations-pools.tf
##resource "aws_vpc_ipam_pool" "secoperations" {
##  address_family      = "ipv4"
##  ipam_scope_id      = aws_vpc_ipam_scope.private.id
##  description        = "secoperations-ipam-pool"
##  source_ipam_pool_id = aws_vpc_ipam_pool.global.id
##  locale             = "None"
##  auto_import        = false
##
##  tags = merge(var.tags, {
##    Name = "${var.environment}-secoperations-ipam-pool"
##  })
##  depends_on = [aws_vpc_ipam_pool_cidr.global]
##}
##
##resource "aws_vpc_ipam_pool_cidr" "secoperations" {
##  ipam_pool_id = aws_vpc_ipam_pool.secoperations.id
##  cidr         = var.pool_configuration.pool_cidrs.secoperations_cidr
##}
##
##resource "aws_vpc_ipam_pool" "security" {
##  address_family      = "ipv4"
##  ipam_scope_id      = aws_vpc_ipam_scope.private.id
##  description        = "security-ipam-pool"
##  source_ipam_pool_id = aws_vpc_ipam_pool.secoperations.id
##  locale             = "None"
##  auto_import        = false
##
##  tags = merge(var.tags, {
##    Name = "${var.environment}-security-ipam-pool"
##  })
##  depends_on = [aws_vpc_ipam_pool.secoperations]
##}
##
##resource "aws_vpc_ipam_pool_cidr" "security" {
##  ipam_pool_id = aws_vpc_ipam_pool.security.id
##  cidr         = var.pool_configuration.pool_cidrs.security_cidr
##  depends_on = [aws_vpc_ipam_pool.security]
##}
##
### Regional security pool
##resource "aws_vpc_ipam_pool" "security_regional" {
##  for_each = var.regional_config
##
##  address_family      = "ipv4"
##  ipam_scope_id      = aws_vpc_ipam_scope.private.id
##  description        = "secoperations-security-${each.key}-ipam-pool"
##  source_ipam_pool_id = aws_vpc_ipam_pool.security.id
##  locale             = each.key
##  auto_import        = true
##
##  tags = merge(var.tags, {
##    Name = "secoperations-security-${each.key}-ipam-pool"
##  })
##  depends_on = [aws_vpc_ipam_pool_cidr.security]
##}
##