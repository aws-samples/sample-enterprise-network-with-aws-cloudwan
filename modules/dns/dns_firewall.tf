# DNS Firewall configuration
resource "aws_route53_resolver_firewall_rule_group" "main" {
  for_each = { for idx, rg in var.dns_firewall_config.rule_groups : rg.name => rg if var.dns_firewall_config.enabled }

  name = each.value.name
  tags = local.common_tags
}

resource "aws_route53_resolver_firewall_domain_list" "main" {
  for_each = { for rule in flatten([
    for rg in var.dns_firewall_config.rule_groups : [
      for r in rg.rules : {
        name    = "${rg.name}-${r.name}"
        domains = r.domain_list
      }
    ]
  ]) : rule.name => rule if var.dns_firewall_config.enabled }

  name    = each.key
  domains = each.value.domains
  tags    = local.common_tags
}

resource "aws_route53_resolver_firewall_rule" "main" {
  for_each = { for rule in flatten([
    for rg in var.dns_firewall_config.rule_groups : [
      for r in rg.rules : {
        name             = r.name
        group_name       = rg.name
        action           = r.action
        priority         = r.priority
        domain_list_name = "${rg.name}-${r.name}"
      }
    ]
  ]) : "${rule.group_name}-${rule.name}" => rule if var.dns_firewall_config.enabled }

  name                    = each.value.name
  action                  = each.value.action
  priority                = each.value.priority
  firewall_rule_group_id  = aws_route53_resolver_firewall_rule_group.main[each.value.group_name].id
  firewall_domain_list_id = aws_route53_resolver_firewall_domain_list.main[each.value.domain_list_name].id
}
