# Data source for ELB service account (needed for S3 bucket policy)
data "aws_elb_service_account" "main" {}









locals {
  # Naming and tagging logic to replace cloudposse modules
  name_parts = compact([
    var.namespace,
    var.environment,
    var.stage,
    var.name
  ])

  name_prefix = join(var.delimiter != null ? var.delimiter : "-", local.name_parts)

  common_tags = merge(
    var.tags,
    var.additional_tag_map,
    {
      Name = local.name_prefix
    }
  )

  # Use provided VPC ID and subnet IDs directly
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # cidrnetmask returns an error for IPv6 addresses
  # cidrhost works with both IPv4 and IPv6, and returns an error if the argument is not a valid IPv4/IPv6 CIDR prefix
  http_ingress_cidr_blocks_v4  = [for cidr in var.http_ingress_cidr_blocks : cidr if can(cidrnetmask(cidr))]
  http_ingress_cidr_blocks_v6  = var.ip_address_type == "dualstack" ? [for cidr in var.http_ingress_cidr_blocks : cidr if !can(cidrnetmask(cidr)) && can(cidrhost(cidr, 0))] : []
  https_ingress_cidr_blocks_v4 = [for cidr in var.https_ingress_cidr_blocks : cidr if can(cidrnetmask(cidr))]
  https_ingress_cidr_blocks_v6 = var.ip_address_type == "dualstack" ? [for cidr in var.https_ingress_cidr_blocks : cidr if !can(cidrnetmask(cidr)) && can(cidrhost(cidr, 0))] : []
}

resource "aws_security_group" "default" {
  count       = var.enabled && var.security_group_enabled ? 1 : 0
  description = "Controls access to the ALB (HTTP/HTTPS)"
  vpc_id      = local.vpc_id
  name        = local.name_prefix
  tags        = local.common_tags
}

resource "aws_security_group_rule" "egress" {
  count             = var.enabled && var.security_group_enabled ? 1 : 0
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from ALB"
  security_group_id = one(aws_security_group.default[*].id)
}

resource "aws_security_group_rule" "http_ingress" {
  count             = var.enabled && var.security_group_enabled && var.http_enabled ? 1 : 0
  type              = "ingress"
  from_port         = var.http_port
  to_port           = var.http_port
  protocol          = "tcp"
  cidr_blocks       = local.http_ingress_cidr_blocks_v4
  ipv6_cidr_blocks  = local.http_ingress_cidr_blocks_v6
  prefix_list_ids   = var.http_ingress_prefix_list_ids
  description       = "Allow HTTP inbound traffic to ALB"
  security_group_id = one(aws_security_group.default[*].id)
}

resource "aws_security_group_rule" "http_ingress_from_security_groups" {
  count                    = var.enabled && var.security_group_enabled && var.http_enabled ? length(var.http_ingress_security_group_ids) : 0
  type                     = "ingress"
  from_port                = var.http_port
  to_port                  = var.http_port
  protocol                 = "tcp"
  source_security_group_id = var.http_ingress_security_group_ids[count.index]
  security_group_id        = one(aws_security_group.default[*].id)
}

resource "aws_security_group_rule" "https_ingress" {
  count             = var.enabled && var.security_group_enabled && var.https_enabled ? 1 : 0
  type              = "ingress"
  from_port         = var.https_port
  to_port           = var.https_port
  protocol          = "tcp"
  cidr_blocks       = local.https_ingress_cidr_blocks_v4
  ipv6_cidr_blocks  = local.https_ingress_cidr_blocks_v6
  prefix_list_ids   = var.https_ingress_prefix_list_ids
  security_group_id = one(aws_security_group.default[*].id)
}

resource "aws_security_group_rule" "https_ingress_from_security_groups" {
  count                    = var.enabled && var.security_group_enabled && var.https_enabled ? length(var.https_ingress_security_group_ids) : 0
  type                     = "ingress"
  from_port                = var.https_port
  to_port                  = var.https_port
  protocol                 = "tcp"
  source_security_group_id = var.https_ingress_security_group_ids[count.index]
  security_group_id        = one(aws_security_group.default[*].id)
}

# Random suffix for globally unique S3 bucket names
resource "random_id" "bucket_suffix" {
  count       = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  bucket = "${local.name_prefix}-logs-${random_id.bucket_suffix[0].hex}"
  tags   = local.common_tags

  force_destroy = var.alb_access_logs_s3_bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null && var.lifecycle_rule_enabled ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "access_logs_lifecycle"
    status = "Enabled"

    filter {
      prefix = var.access_logs_prefix
    }

    # Abort incomplete multipart uploads after 7 days (CKV_AWS_300)
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    transition {
      days          = var.standard_transition_days
      storage_class = "STANDARD_IA"
    }

    dynamic "transition" {
      for_each = var.enable_glacier_transition ? [1] : []
      content {
        days          = var.glacier_transition_days
        storage_class = "GLACIER"
      }
    }

    expiration {
      days = var.expiration_days
    }

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "access_logs" {
  count  = var.enabled && var.access_logs_enabled && var.access_logs_s3_bucket_id == null ? 1 : 0
  bucket = aws_s3_bucket.access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowALBLogging"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_elb_service_account.main.id}:root" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.access_logs[0].arn}/*"
      },
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.access_logs[0].arn,
          "${aws_s3_bucket.access_logs[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_lb" "default" {
  count              = var.enabled ? 1 : 0
  name               = var.load_balancer_name == "" ? substr(local.name_prefix, 0, var.load_balancer_name_max_length) : substr(var.load_balancer_name, 0, var.load_balancer_name_max_length)
  tags               = local.common_tags
  internal           = var.internal
  load_balancer_type = "application"

  security_groups = compact(
    concat(var.security_group_ids, [one(aws_security_group.default[*].id)]),
  )

  subnets                          = local.subnet_ids
  enable_cross_zone_load_balancing = var.cross_zone_load_balancing_enabled
  enable_http2                     = var.http2_enabled
  idle_timeout                     = var.idle_timeout
  ip_address_type                  = var.ip_address_type
  enable_deletion_protection       = true
  drop_invalid_header_fields       = var.drop_invalid_header_fields
  preserve_host_header             = var.preserve_host_header
  xff_header_processing_mode       = var.xff_header_processing_mode
  client_keep_alive                = var.client_keep_alive

  access_logs {
    bucket  = try(element(compact([var.access_logs_s3_bucket_id, one(aws_s3_bucket.access_logs[*].id)]), 0), "")
    prefix  = var.access_logs_prefix
    enabled = var.access_logs_enabled
  }

  dynamic "minimum_load_balancer_capacity" {
    for_each = var.reserved_capacity_units == null ? [] : [var.reserved_capacity_units]
    content {
      capacity_units = minimum_load_balancer_capacity.value
    }
  }
}

# Local values for target group naming

resource "aws_lb_target_group" "default" {
  count                             = var.enabled && var.default_target_group_enabled ? 1 : 0
  name                              = var.target_group_name == "" ? substr("${local.name_prefix}-default", 0, var.target_group_name_max_length) : substr(var.target_group_name, 0, var.target_group_name_max_length)
  port                              = var.target_group_port
  protocol                          = var.target_group_protocol
  protocol_version                  = var.target_group_protocol_version
  vpc_id                            = local.vpc_id
  target_type                       = var.target_group_target_type
  load_balancing_algorithm_type     = var.load_balancing_algorithm_type
  load_balancing_anomaly_mitigation = var.load_balancing_anomaly_mitigation
  deregistration_delay              = var.deregistration_delay
  slow_start                        = var.slow_start

  health_check {
    protocol            = var.health_check_protocol != null ? var.health_check_protocol : var.target_group_protocol
    path                = var.health_check_path
    port                = var.health_check_port
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
  }

  dynamic "stickiness" {
    for_each = var.stickiness == null ? [] : [var.stickiness]
    content {
      type            = "lb_cookie"
      cookie_duration = stickiness.value.cookie_duration
      enabled         = var.target_group_protocol == "TCP" ? false : stickiness.value.enabled
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    var.target_group_additional_tags
  )
}

# Multiple target groups
resource "aws_lb_target_group" "additional" {
  for_each = var.enabled ? var.target_groups : {}

  name                              = each.value.name != null ? each.value.name : substr("${local.name_prefix}-${each.key}", 0, var.target_group_name_max_length)
  port                              = each.value.port
  protocol                          = each.value.protocol
  protocol_version                  = each.value.protocol_version
  vpc_id                            = local.vpc_id
  target_type                       = each.value.target_type
  load_balancing_algorithm_type     = each.value.load_balancing_algorithm_type
  load_balancing_anomaly_mitigation = each.value.load_balancing_anomaly_mitigation
  deregistration_delay              = each.value.deregistration_delay
  slow_start                        = each.value.slow_start

  health_check {
    enabled             = each.value.health_check.enabled
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol != null ? each.value.health_check.protocol : each.value.protocol
    matcher             = each.value.health_check.matcher
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      type            = "lb_cookie"
      cookie_duration = stickiness.value.cookie_duration
      enabled         = each.value.protocol == "TCP" ? false : stickiness.value.enabled
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    each.value.tags
  )
}

resource "aws_lb_listener" "http_forward" {
  count = (
    var.enabled &&
    var.http_enabled &&
    var.http_redirect != true &&
    (var.listener_http_fixed_response != null || var.default_target_group_enabled)
    ? 1 : 0
  )
  load_balancer_arn = one(aws_lb.default[*].arn)
  port              = var.http_port
  protocol          = "HTTP"
  tags              = merge(local.common_tags, var.listener_additional_tags)

  default_action {
    # target_group_arn is required when type is forward
    target_group_arn = var.listener_http_fixed_response != null ? null : one(aws_lb_target_group.default[*].arn)
    type             = var.listener_http_fixed_response != null ? "fixed-response" : "forward"

    dynamic "fixed_response" {
      for_each = var.listener_http_fixed_response != null ? [var.listener_http_fixed_response] : []
      content {
        content_type = fixed_response.value["content_type"]
        message_body = fixed_response.value["message_body"]
        status_code  = fixed_response.value["status_code"]
      }
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.enabled && var.http_enabled && var.http_redirect == true ? 1 : 0
  load_balancer_arn = one(aws_lb.default[*].arn)
  port              = var.http_port
  protocol          = "HTTP"
  tags              = merge(local.common_tags, var.listener_additional_tags)

  default_action {
    target_group_arn = one(aws_lb_target_group.default[*].arn)
    type             = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.enabled && var.https_enabled ? 1 : 0
  load_balancer_arn = one(aws_lb.default[*].arn)

  port            = var.https_port
  protocol        = "HTTPS"
  ssl_policy      = var.https_ssl_policy != null ? var.https_ssl_policy : "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = var.certificate_arn
  tags            = merge(local.common_tags, var.listener_additional_tags)

  default_action {
    target_group_arn = var.listener_https_fixed_response != null || var.listener_https_redirect != null ? null : one(aws_lb_target_group.default[*].arn)
    type             = var.listener_https_fixed_response != null ? "fixed-response" : var.listener_https_redirect != null ? "redirect" : "forward"

    dynamic "fixed_response" {
      for_each = var.listener_https_fixed_response != null ? [var.listener_https_fixed_response] : []
      content {
        content_type = fixed_response.value["content_type"]
        message_body = fixed_response.value["message_body"]
        status_code  = fixed_response.value["status_code"]
      }
    }

    dynamic "redirect" {
      for_each = var.listener_https_redirect != null ? [var.listener_https_redirect] : []
      content {
        host        = redirect.value["host"]
        path        = redirect.value["path"]
        port        = redirect.value["port"]
        protocol    = redirect.value["protocol"]
        query       = redirect.value["query"]
        status_code = redirect.value["status_code"]
      }
    }
  }
}

resource "aws_lb_listener_certificate" "https_sni" {
  count           = var.enabled && var.https_enabled && length(var.additional_certs) > 0 ? length(var.additional_certs) : 0
  listener_arn    = one(aws_lb_listener.https[*].arn)
  certificate_arn = var.additional_certs[count.index]
}

# Listener rules for routing to different target groups
resource "aws_lb_listener_rule" "rules" {
  for_each = var.enabled ? {
    for k, v in var.listener_rules : k => v
    if(
      (v.listener_type == "https" && var.https_enabled) ||
      (v.listener_type == "http" && var.http_enabled)
    )
  } : {}

  listener_arn = each.value.listener_type == "https" ? one(aws_lb_listener.https[*].arn) : (
    var.http_redirect ? one(aws_lb_listener.http_redirect[*].arn) : one(aws_lb_listener.http_forward[*].arn)
  )
  priority = each.value.priority

  action {
    type = each.value.action_type

    # Forward action
    target_group_arn = each.value.action_type == "forward" ? aws_lb_target_group.additional[each.value.target_group_key].arn : null

    # Redirect action
    dynamic "redirect" {
      for_each = each.value.action_type == "redirect" && each.value.redirect != null ? [each.value.redirect] : []
      content {
        host        = redirect.value.host
        path        = redirect.value.path
        port        = redirect.value.port
        protocol    = redirect.value.protocol
        query       = redirect.value.query
        status_code = redirect.value.status_code
      }
    }

    # Fixed response action
    dynamic "fixed_response" {
      for_each = each.value.action_type == "fixed-response" && each.value.fixed_response != null ? [each.value.fixed_response] : []
      content {
        content_type = fixed_response.value.content_type
        message_body = fixed_response.value.message_body
        status_code  = fixed_response.value.status_code
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.conditions
    content {
      dynamic "host_header" {
        for_each = condition.value.field == "host-header" ? [condition.value] : []
        content {
          values = host_header.value.values
        }
      }

      dynamic "path_pattern" {
        for_each = condition.value.field == "path-pattern" ? [condition.value] : []
        content {
          values = path_pattern.value.values
        }
      }

      dynamic "http_request_method" {
        for_each = condition.value.field == "http-request-method" ? [condition.value] : []
        content {
          values = http_request_method.value.values
        }
      }

      dynamic "query_string" {
        for_each = condition.value.field == "query-string" ? [condition.value] : []
        content {
          key   = try(split("=", condition.value.values[0])[0], null)
          value = try(split("=", condition.value.values[0])[1], condition.value.values[0])
        }
      }

      dynamic "http_header" {
        for_each = condition.value.field == "http-header" ? [condition.value] : []
        content {
          http_header_name = condition.value.values[0]
          values           = slice(condition.value.values, 1, length(condition.value.values))
        }
      }
    }
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rule-${each.key}" })
}
