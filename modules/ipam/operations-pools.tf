### operations-pools.tf
##resource "aws_vpc_ipam_pool" "operations" {
##  address_family      = "ipv4"
##  ipam_scope_id      = aws_vpc_ipam_scope.private.id
##  description        = "operations-ipam-pool"
##  source_ipam_pool_id = aws_vpc_ipam_pool.global.id
##  locale             = var.primary_region
##  auto_import        = false
##
##  tags = merge(var.tags, {
##    Name = "${var.environment}-operations-ipam-pool"
##  })
##  depends_on = [aws_vpc_ipam_pool_cidr.global]
##}
##
##resource "aws_vpc_ipam_pool_cidr" "operations" {
##  ipam_pool_id = aws_vpc_ipam_pool.operations.id
##  cidr         = var.pool_configuration.pool_cidrs.operations_cidr
##  depends_on = [aws_vpc_ipam_pool.operations]
##}
##