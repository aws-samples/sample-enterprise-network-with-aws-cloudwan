locals {
  availability_zones = var.availability_zones

  tags = merge(var.tags, {
    Environment = var.environment
    Terraform   = "true"
    Project     = "network-egress"
  })
}