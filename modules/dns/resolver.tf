locals {
  name_prefix                = try("${var.tags["Environment"]}-resolver", "resolver")
  inbound_endpoints_enabled  = try(var.resolver_config.inbound.enabled, false)
  outbound_endpoints_enabled = try(var.resolver_config.outbound.enabled, false)
}

# Inbound resolver endpoint
resource "aws_route53_resolver_endpoint" "inbound" {
  count = local.inbound_endpoints_enabled ? 1 : 0

  name               = "${local.name_prefix}-inbound"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.resolver_config.inbound.ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = ip_address.value.ip
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-inbound"
  })

  depends_on = [var.subnet_ids]
}

# Outbound resolver endpoint
resource "aws_route53_resolver_endpoint" "outbound" {
  count = local.outbound_endpoints_enabled ? 1 : 0

  name               = "${local.name_prefix}-outbound"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = var.resolver_config.outbound.ip_addresses
    content {
      subnet_id = ip_address.value.subnet_id
      ip        = ip_address.value.ip
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-outbound"
  })
}

# Resolver rules for outbound endpoints
resource "aws_route53_resolver_rule" "outbound" {
  for_each = { for rule in var.resolver_config.outbound.rules : rule.domain_name => rule }

  domain_name          = each.key
  name                 = coalesce(each.value.name, replace(each.key, ".", "-"))
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[0].id

  dynamic "target_ip" {
    for_each = each.value.target_ips
    content {
      ip   = target_ip.value.ip
      port = target_ip.value.port
    }
  }

  tags = merge(var.tags, {
    Name = coalesce(each.value.name, replace(each.key, ".", "-"))
  })
  depends_on = [var.subnet_ids]
}

# Associate resolver rules with VPC
resource "aws_route53_resolver_rule_association" "outbound" {
  for_each = aws_route53_resolver_rule.outbound

  resolver_rule_id = each.value.id
  vpc_id           = var.vpc_id

  depends_on = [aws_route53_resolver_endpoint.outbound]
}