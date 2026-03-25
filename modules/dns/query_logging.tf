resource "aws_route53_resolver_query_log_config" "main" {
  count = var.query_logging_config.enabled ? 1 : 0

  name            = coalesce(var.query_logging_config.name, "${local.name_prefix}-query-logging")
  destination_arn = var.query_logging_config.destination_arn
  tags            = local.common_tags
}

resource "aws_route53_resolver_query_log_config_association" "main" {
  count = var.query_logging_config.enabled ? 1 : 0

  resolver_query_log_config_id = aws_route53_resolver_query_log_config.main[0].id
  resource_id                  = var.vpc_id
}