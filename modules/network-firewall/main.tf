# AWS Network Firewall Module
# Reusable module for deploying Network Firewall in any VPC

# KMS Key for Network Firewall Encryption
resource "aws_kms_key" "network_firewall" {
  description             = "KMS key for Network Firewall encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-network-firewall-key"
  })
}

resource "aws_kms_alias" "network_firewall" {
  name          = "alias/${var.name_prefix}-network-firewall"
  target_key_id = aws_kms_key.network_firewall.key_id
}

# CloudWatch Log Group for Network Firewall
resource "aws_cloudwatch_log_group" "network_firewall" {
  name              = "/aws/network-firewall/${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.network_firewall.arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-network-firewall-logs"
  })
}

# Network Firewall Rule Group - Allow All (for DEFAULT_ACTION_ORDER)
# NOTE: This rule allows all traffic at IP level which causes all traffic to match at lower layer
# AWS recommends using protocol-specific rules instead
resource "aws_networkfirewall_rule_group" "allow_all" {
  count    = var.enable_test_block_rules || var.rule_order == "STRICT_ORDER" || length(var.allowed_domains) > 0 ? 0 : 1
  capacity = 100
  name     = "${var.name_prefix}-allow-all"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      stateful_rule {
        action = "PASS"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "IP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1"
        }
      }
    }

    stateful_rule_options {
      rule_order = "DEFAULT_ACTION_ORDER"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-allow-all-rule"
  })
}

# Network Firewall Rule Group - Allow Specific Domains (Recommended by AWS)
# This replaces the allow-all rule at IP level with protocol-specific rules
resource "aws_networkfirewall_rule_group" "allow_domains" {
  count    = length(var.allowed_domains) > 0 ? 1 : 0
  capacity = 1000
  name     = "${var.name_prefix}-allow-domains"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        }
      }
    }

    rules_source {
      rules_string = join("\n", concat(
        # Allow HTTP traffic to specified domains
        [for idx, domain in var.allowed_domains :
          "pass http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:\"${domain}\"; endswith; msg:\"Allow HTTP to ${domain}\"; sid:${10000 + idx}; rev:1;)"
        ],
        # Allow TLS/HTTPS traffic to specified domains
        [for idx, domain in var.allowed_domains :
          "pass tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:\"${domain}\"; endswith; msg:\"Allow TLS to ${domain}\"; sid:${20000 + idx}; rev:1;)"
        ],
        # Allow DNS queries
        ["pass udp $HOME_NET any -> any 53 (msg:\"Allow DNS UDP\"; sid:30000; rev:1;)"],
        ["pass tcp $HOME_NET any -> any 53 (msg:\"Allow DNS TCP\"; sid:30001; rev:1;)"],
        # Allow NTP
        ["pass udp $HOME_NET any -> any 123 (msg:\"Allow NTP\"; sid:30002; rev:1;)"],
        # Allow ICMP for troubleshooting
        ["pass icmp $HOME_NET any -> any any (msg:\"Allow ICMP\"; sid:30003; rev:1;)"]
      ))
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-allow-domains-rule"
  })
}

# Network Firewall Rule Group - Block Specific Domains with ALERT
# This generates alerts for blocked domains before drop_established catches them
resource "aws_networkfirewall_rule_group" "block_domains_explicit" {
  count    = length(var.blocked_domains) > 0 ? 1 : 0
  capacity = 1000
  name     = "${var.name_prefix}-block-domains-explicit"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
        }
      }
    }

    rules_source {
      rules_string = join("\n", concat(
        # Drop HTTP traffic to blocked domains with alert
        [for idx, domain in var.blocked_domains :
          "drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:\"${domain}\"; endswith; msg:\"BLOCKED HTTP to ${domain}\"; sid:${40000 + idx}; rev:1;)"
        ],
        # Drop TLS/HTTPS traffic to blocked domains with alert
        [for idx, domain in var.blocked_domains :
          "drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:\"${domain}\"; endswith; msg:\"BLOCKED TLS to ${domain}\"; sid:${50000 + idx}; rev:1;)"
        ]
      ))
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-block-domains-explicit-rule"
  })
}

# Network Firewall Rule Group - Allow All for STRICT_ORDER (DEPRECATED)
# AWS recommends NOT using this - use allow_domains instead
resource "aws_networkfirewall_rule_group" "allow_all_strict" {
  count    = var.rule_order == "STRICT_ORDER" && length(var.allowed_domains) == 0 ? 1 : 0
  capacity = 100
  name     = "${var.name_prefix}-allow-all-strict"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      stateful_rule {
        action = "PASS"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "IP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:9999"
        }
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-allow-all-strict-rule"
  })
}

# Custom Blocking Rules
resource "aws_networkfirewall_rule_group" "custom_block_rules" {
  count    = length(var.custom_block_rules) > 0 ? 1 : 0
  capacity = 100
  name     = "${var.name_prefix}-custom-block"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      dynamic "stateful_rule" {
        for_each = var.custom_block_rules
        content {
          action = "DROP"
          header {
            destination      = stateful_rule.value.destination
            destination_port = "ANY"
            direction        = "FORWARD"
            protocol         = "IP"
            source           = stateful_rule.value.source
            source_port      = "ANY"
          }
          rule_option {
            keyword = "sid:${stateful_rule.key + 100}"
          }
        }
      }
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-custom-block-rules"
  })
}

# Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${var.name_prefix}-policy"

  encryption_configuration {
    key_id = aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    # Custom blocking rules (priority only for STRICT_ORDER)
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.custom_block_rules) > 0 ? [1] : []
      content {
        priority     = var.rule_order == "STRICT_ORDER" ? 1 : null
        resource_arn = aws_networkfirewall_rule_group.custom_block_rules[0].arn
      }
    }

    # Explicit blocked domains rule group (generates alerts before drop)
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.blocked_domains) > 0 ? [1] : []
      content {
        priority     = var.rule_order == "STRICT_ORDER" ? 5 : null
        resource_arn = aws_networkfirewall_rule_group.block_domains_explicit[0].arn
      }
    }

    # Test blocking rules with priority (for STRICT_ORDER)
    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "STRICT_ORDER" ? [1] : []
      content {
        priority     = 10
        resource_arn = aws_networkfirewall_rule_group.block_domains[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "STRICT_ORDER" ? [1] : []
      content {
        priority     = 20
        resource_arn = aws_networkfirewall_rule_group.block_ips[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "STRICT_ORDER" ? [1] : []
      content {
        priority     = 30
        resource_arn = aws_networkfirewall_rule_group.block_ports[0].arn
      }
    }

    # Allowed domains rule group (recommended by AWS - replaces allow-all at IP level)
    dynamic "stateful_rule_group_reference" {
      for_each = length(var.allowed_domains) > 0 ? [1] : []
      content {
        priority     = var.rule_order == "STRICT_ORDER" ? 100 : null
        resource_arn = aws_networkfirewall_rule_group.allow_domains[0].arn
      }
    }

    # Allow-all rule with lowest priority (DEPRECATED - only used if no allowed_domains specified)
    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "STRICT_ORDER" && length(var.allowed_domains) == 0 ? [1] : []
      content {
        priority     = 100
        resource_arn = aws_networkfirewall_rule_group.allow_all_strict[0].arn
      }
    }

    # Test blocking rules without priority (for DEFAULT_ACTION_ORDER)
    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "DEFAULT_ACTION_ORDER" ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.block_domains[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "DEFAULT_ACTION_ORDER" ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.block_ips[0].arn
      }
    }

    dynamic "stateful_rule_group_reference" {
      for_each = var.enable_test_block_rules && var.rule_order == "DEFAULT_ACTION_ORDER" ? [1] : []
      content {
        resource_arn = aws_networkfirewall_rule_group.block_ports[0].arn
      }
    }

    # Allow-all rule (only for DEFAULT_ACTION_ORDER without test rules and no allowed_domains)
    dynamic "stateful_rule_group_reference" {
      for_each = (var.rule_order == "DEFAULT_ACTION_ORDER" && !var.enable_test_block_rules && length(var.allowed_domains) == 0) || (var.rule_order == "STRICT_ORDER" && !var.enable_test_block_rules && length(var.allowed_domains) == 0) ? [1] : []
      content {
        priority     = var.rule_order == "STRICT_ORDER" ? 100 : null
        resource_arn = var.rule_order == "STRICT_ORDER" ? aws_networkfirewall_rule_group.allow_all_strict[0].arn : aws_networkfirewall_rule_group.allow_all[0].arn
      }
    }

    # Add custom rule groups if provided
    dynamic "stateful_rule_group_reference" {
      for_each = var.custom_rule_group_arns
      content {
        resource_arn = stateful_rule_group_reference.value
      }
    }

    stateful_engine_options {
      rule_order              = var.rule_order
      stream_exception_policy = "CONTINUE"
    }

    # Stateful default actions - Enhanced logging configuration
    # Valid actions for STRICT_ORDER:
    # - aws:drop_established: Block non-matching traffic
    # - aws:alert_established: Log ALERT_ESTABLISHED for packets in established connections
    # Note: aws:alert_all is NOT a valid stateful_default_action
    # To get comprehensive logging, use logging configuration with both FLOW and ALERT log types
    stateful_default_actions = var.rule_order == "STRICT_ORDER" ? compact([
      var.enable_drop_established ? "aws:drop_established" : null,
      var.enable_alert_established ? "aws:alert_established" : null
    ]) : null
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-firewall-policy"
  })
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name                = "${var.name_prefix}-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id              = var.vpc_id

  encryption_configuration {
    key_id = aws_kms_key.network_firewall.arn
    type   = "CUSTOMER_KMS"
  }

  # Deploy firewall endpoints in specified subnets (one per AZ)
  dynamic "subnet_mapping" {
    for_each = var.subnet_ids
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-firewall"
  })
}

# Network Firewall Logging Configuration
resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.network_firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.network_firewall.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}

# Extract Network Firewall Endpoint IDs by AZ
locals {
  # Get all sync states and extract endpoint IDs
  # sync_states is a map, we need to iterate and get endpoint IDs from attachments
  firewall_endpoint_ids_list = flatten([
    for az_key, sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states : [
      for attachment in sync_state.attachment : attachment.endpoint_id
    ]
  ])

  # For backward compatibility, create a map using index as key
  firewall_endpoints = {
    for idx, endpoint_id in local.firewall_endpoint_ids_list :
    "endpoint-${idx}" => endpoint_id
  }
}
