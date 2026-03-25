# Test blocking rules for Network Firewall validation
# These rules can be enabled to test that the firewall is actually blocking traffic
# Using AWS-recommended Suricata format with flow:to_server,established

# Domain blocking using Suricata rules with proper flow keywords
resource "aws_networkfirewall_rule_group" "block_domains" {
  count    = var.enable_test_block_rules ? 1 : 0
  capacity = 100
  name     = "${var.name_prefix}-block-domains"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
      ip_sets {
        key = "EXTERNAL_NET"
        ip_set {
          definition = ["0.0.0.0/0"]
        }
      }
    }

    rules_source {
      rules_string = <<-EOT
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:".facebook.com"; endswith; msg:"Block Facebook HTTP"; flow:to_server,established; sid:3001; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"facebook.com"; startswith; endswith; msg:"Block Facebook HTTP exact"; flow:to_server,established; sid:3002; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; dotprefix; content:".facebook.com"; endswith; msg:"Block Facebook HTTPS"; flow:to_server,established; sid:3003; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:"facebook.com"; startswith; endswith; msg:"Block Facebook HTTPS exact"; flow:to_server,established; sid:3004; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:".instagram.com"; endswith; msg:"Block Instagram HTTP"; flow:to_server,established; sid:3005; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"instagram.com"; startswith; endswith; msg:"Block Instagram HTTP exact"; flow:to_server,established; sid:3006; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; dotprefix; content:".instagram.com"; endswith; msg:"Block Instagram HTTPS"; flow:to_server,established; sid:3007; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:"instagram.com"; startswith; endswith; msg:"Block Instagram HTTPS exact"; flow:to_server,established; sid:3008; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:".twitter.com"; endswith; msg:"Block Twitter HTTP"; flow:to_server,established; sid:3009; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"twitter.com"; startswith; endswith; msg:"Block Twitter HTTP exact"; flow:to_server,established; sid:3010; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; dotprefix; content:".twitter.com"; endswith; msg:"Block Twitter HTTPS"; flow:to_server,established; sid:3011; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:"twitter.com"; startswith; endswith; msg:"Block Twitter HTTPS exact"; flow:to_server,established; sid:3012; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; dotprefix; content:".x.com"; endswith; msg:"Block X.com HTTP"; flow:to_server,established; sid:3013; rev:1;)
        drop http $HOME_NET any -> $EXTERNAL_NET any (http.host; content:"x.com"; startswith; endswith; msg:"Block X.com HTTP exact"; flow:to_server,established; sid:3014; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; dotprefix; content:".x.com"; endswith; msg:"Block X.com HTTPS"; flow:to_server,established; sid:3015; rev:1;)
        drop tls $HOME_NET any -> $EXTERNAL_NET any (tls.sni; content:"x.com"; startswith; endswith; msg:"Block X.com HTTPS exact"; flow:to_server,established; sid:3016; rev:1;)
      EOT
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-block-domains"
    Type = "test-rule"
  })
}

# Block specific IP addresses (example: block Google DNS)
resource "aws_networkfirewall_rule_group" "block_ips" {
  count    = var.enable_test_block_rules ? 1 : 0
  capacity = 100
  name     = "${var.name_prefix}-block-ips"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      # Block 8.8.8.8 - All protocols including ICMP
      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.8.8/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "ICMP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1001"
        }
      }

      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.8.8/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1002"
        }
      }

      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.8.8/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "UDP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1003"
        }
      }

      # Block 8.8.4.4 - All protocols including ICMP
      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.4.4/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "ICMP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1004"
        }
      }

      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.4.4/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1005"
        }
      }

      stateful_rule {
        action = "DROP"
        header {
          destination      = "8.8.4.4/32"
          destination_port = "ANY"
          direction        = "FORWARD"
          protocol         = "UDP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:1006"
        }
      }
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-block-ips"
    Type = "test-rule"
  })
}

# Block specific port (example: block port 22 SSH)
resource "aws_networkfirewall_rule_group" "block_ports" {
  count    = var.enable_test_block_rules ? 1 : 0
  capacity = 100
  name     = "${var.name_prefix}-block-ports"
  type     = "STATEFUL"

  encryption_configuration {
    key_id = var.kms_key_id
    type   = "CUSTOMER_KMS"
  }

  rule_group {
    rules_source {
      stateful_rule {
        action = "DROP"
        header {
          destination      = "ANY"
          destination_port = "22"
          direction        = "FORWARD"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword = "sid:2001"
        }
      }
    }

    stateful_rule_options {
      rule_order = var.rule_order
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-block-ports"
    Type = "test-rule"
  })
}
