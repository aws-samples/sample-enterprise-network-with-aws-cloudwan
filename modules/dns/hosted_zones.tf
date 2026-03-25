# Private hosted zones
resource "aws_route53_zone" "private" {
  for_each = { for zone in var.private_hosted_zones : zone.name => zone }

  name          = each.key
  comment       = each.value.comment
  force_destroy = each.value.force_destroy

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name = each.key
  })
}

# Record sets from variable
resource "aws_route53_record" "main" {
  for_each = var.record_sets

  zone_id = aws_route53_zone.private[each.value.zone_name].id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records

  dynamic "alias" {
    for_each = each.value.alias != null ? [each.value.alias] : []
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = alias.value.evaluate_target_health
    }
  }
  depends_on = [aws_route53_zone.private]
}

# Auto-generated records for VPC endpoints
# Note: AWS VPC endpoints automatically handle DNS resolution for amazonaws.com domains
# We don't need to create custom DNS records for AWS service endpoints
# The VPC endpoint service automatically provides the correct DNS resolution



# VPC associations for private hosted zones
resource "aws_route53_zone_association" "private" {
  for_each = {
    for idx, zone in var.private_hosted_zones : zone.name => zone
    if length(try(zone.vpc_associations, [])) > 0
  }

  zone_id = aws_route53_zone.private[each.key].id
  vpc_id  = var.vpc_id # Use the VPC ID passed to the module instead of from associations
}