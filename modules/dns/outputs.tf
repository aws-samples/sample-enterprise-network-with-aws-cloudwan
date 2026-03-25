output "inbound_resolver_endpoint" {
  description = "Inbound resolver endpoint details"
  value = local.inbound_endpoints_enabled ? {
    id           = aws_route53_resolver_endpoint.inbound[0].id
    arn          = aws_route53_resolver_endpoint.inbound[0].arn
    ip_addresses = aws_route53_resolver_endpoint.inbound[0].ip_address[*].ip
  } : null
}

output "outbound_resolver_endpoint" {
  description = "Outbound resolver endpoint details"
  value = local.outbound_endpoints_enabled ? {
    id           = aws_route53_resolver_endpoint.outbound[0].id
    arn          = aws_route53_resolver_endpoint.outbound[0].arn
    ip_addresses = aws_route53_resolver_endpoint.outbound[0].ip_address[*].ip
  } : null
}

output "resolver_rules" {
  description = "Map of created resolver rules"
  value = {
    for name, rule in aws_route53_resolver_rule.outbound : name => {
      id   = rule.id
      arn  = rule.arn
      name = rule.name
    }
  }
}

output "private_hosted_zones" {
  description = "Map of created private hosted zones"
  value = {
    for name, zone in aws_route53_zone.private : name => {
      id           = zone.id
      name         = zone.name
      name_servers = zone.name_servers
    }
  }
}

output "security_group_id" {
  description = "ID of the security group created for resolver endpoints"
  value       = aws_security_group.resolver.id
}

# Add to existing outputs.tf

output "query_logging_config" {
  description = "Query logging configuration details"
  value = var.query_logging_config.enabled ? {
    id  = aws_route53_resolver_query_log_config.main[0].id
    arn = aws_route53_resolver_query_log_config.main[0].arn
  } : null
}

output "dns_firewall_rule_groups" {
  description = "DNS firewall rule groups"
  value = var.dns_firewall_config.enabled ? {
    for name, rg in aws_route53_resolver_firewall_rule_group.main : name => {
      id  = rg.id
      arn = rg.arn
    }
  } : null
}

output "ram_share" {
  description = "RAM share details for resolver rules"
  value = var.enable_ram_sharing ? {
    arn = aws_ram_resource_share.resolver_rules[0].arn
  } : null
}
