locals {

  #inbound_endpoints_enabled  = var.resolver_config.inbound.enabled
  #outbound_endpoints_enabled = var.resolver_config.outbound.enabled

  common_tags = merge(var.tags, {
    Module = "dns"
  })
}

# Security group for resolver endpoints
resource "aws_security_group" "resolver" {
  name_prefix = "${local.name_prefix}-sg-"
  description = "Security group for Route 53 Resolver endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow DNS TCP from VPC"
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Allow DNS UDP from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Data source for VPC
data "aws_vpc" "selected" {
  id = var.vpc_id
}
