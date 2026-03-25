resource "aws_ram_resource_share" "resolver_rules" {
  count = var.enable_ram_sharing ? 1 : 0

  name                      = "${local.name_prefix}-resolver-rules-share"
  allow_external_principals = false

  tags = local.common_tags
}

resource "aws_ram_resource_association" "resolver_rules" {
  for_each = var.enable_ram_sharing ? aws_route53_resolver_rule.outbound : {}

  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.resolver_rules[0].arn
}