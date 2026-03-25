# AWS Network Firewall Module

Reusable Terraform module for deploying AWS Network Firewall in any VPC.

## Features

- Deploys Network Firewall with multi-AZ endpoints
- CloudWatch logging (FLOW and ALERT logs)
- Allow-all rule group for testing (replace with production rules)
- Optional test blocking rules for validation (domains, IPs, ports)
- Configurable rule order (DEFAULT_ACTION_ORDER or STRICT_ORDER)
- Support for custom rule groups
- Outputs firewall endpoint IDs for route table configuration

## Usage

### Basic Example

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  name_prefix = "[FIREWALL_NAME_PREFIX]"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = values(module.vpc.subnets["firewall"])
  
  tags = {
    Environment = "production"
    Purpose     = "internet-egress-inspection"
  }
}
```

### With Test Blocking Rules

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  name_prefix             = "[FIREWALL_NAME_PREFIX]"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = values(module.vpc.subnets["firewall"])
  enable_test_block_rules = true  # Enable test blocking rules
  
  tags = {
    Environment = "production"
    Purpose     = "internet-egress-inspection"
  }
}
```

Test blocking rules include:
- **Domains**: facebook.com, twitter.com, instagram.com
- **IPs**: 8.8.8.8, 8.8.4.4 (Google DNS)
- **Ports**: TCP port 22 (SSH)

### With Custom Rule Groups

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  name_prefix            = "[FIREWALL_NAME_PREFIX]"
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = values(module.vpc.subnets["inspection"])
  log_retention_days     = 90
  rule_order             = "DEFAULT_ACTION_ORDER"
  custom_rule_group_arns = [
    aws_networkfirewall_rule_group.custom.arn
  ]
  
  tags = {
    Environment = "production"
    Purpose     = "east-west-inspection"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name_prefix | Prefix for resource names | string | - | yes |
| vpc_id | VPC ID where firewall will be deployed | string | - | yes |
| subnet_ids | List of subnet IDs for firewall endpoints | list(string) | - | yes |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| rule_order | Rule order (DEFAULT_ACTION_ORDER or STRICT_ORDER) | string | DEFAULT_ACTION_ORDER | no |
| enable_test_block_rules | Enable test blocking rules for validation | bool | false | no |
| custom_rule_group_arns | List of custom rule group ARNs | list(string) | [] | no |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| firewall_id | Network Firewall ID |
| firewall_arn | Network Firewall ARN |
| firewall_name | Network Firewall name |
| firewall_policy_arn | Firewall policy ARN |
| firewall_endpoints | Map of AZ to endpoint ID |
| firewall_endpoint_ids | List of endpoint IDs |
| log_group_name | CloudWatch log group name |
| log_group_arn | CloudWatch log group ARN |

## Traffic Flow

### Egress VPC (Internet-bound traffic)

```
CloudWAN → Transit Subnet → Network Firewall → Firewall Subnet → NAT Gateway → Internet
```

**Route Tables:**
- Transit subnets: `0.0.0.0/0` → Network Firewall endpoint
- Firewall subnets: `0.0.0.0/0` → NAT Gateway

### Inspection VPC (East-west traffic)

```
CloudWAN → Transit Subnet → Network Firewall → Inspection Subnet → CloudWAN
```

**Route Tables:**
- Transit subnets: `10.0.0.0/8` → Network Firewall endpoint
- Inspection subnets: `10.0.0.0/8` → CloudWAN

## Production Hardening

Replace the allow-all rule with production rules:

```hcl
# Create custom rule group
resource "aws_networkfirewall_rule_group" "production" {
  capacity = 1000
  name     = "production-rules"
  type     = "STATEFUL"
  
  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = ["malicious.com", "badsite.net"]
      }
    }
  }
}

# Use AWS Managed Rule Groups
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  # ... other configuration ...
  
  custom_rule_group_arns = [
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/AbusedLegitMalwareDomainsActionOrder",
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatSignaturesMalwareActionOrder",
    aws_networkfirewall_rule_group.production.arn
  ]
}
```

## Cost

- **Firewall Endpoint**: $0.395/hour per AZ (~$290/month per AZ)
- **Data Processing**: $0.065/GB
- **3 AZs**: ~$865/month + data processing

## Notes

- Firewall endpoints are deployed in the specified subnets (one per AZ)
- Allow-all rule is for testing only - replace with production rules
- CloudWatch logs are enabled for both FLOW and ALERT logs
- Rule order DEFAULT_ACTION_ORDER is recommended for 5-tuple rules
