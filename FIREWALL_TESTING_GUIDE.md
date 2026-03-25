# Network Firewall Testing Guide

## Overview
This guide explains how to enable test blocking rules to validate that Network Firewall is properly inspecting traffic in both Egress and Inspection VPCs.

## Test Blocking Rules

The Network Firewall module includes optional test blocking rules that can be enabled to verify traffic inspection:

1. **Domain Blocking**: Blocks facebook.com, twitter.com, instagram.com
2. **IP Blocking**: Blocks Google DNS servers (8.8.8.8, 8.8.4.4)
3. **Port Blocking**: Blocks TCP port 22 (SSH)

## How to Enable Test Rules

### For Egress VPC (Internet Traffic Inspection)

Edit `modules/account-tf-wrapper/network-egress/network-firewall.tf`:

```terraform
module "network_firewall" {
  count  = local.enable_network_firewall ? 1 : 0
  source = "../../network-firewall"
  
  providers = {
    aws = aws.network-services
  }
  
  name_prefix        = local.name_prefix
  vpc_id             = module.egress_vpc.vpc_id
  subnet_ids         = values(module.egress_vpc.subnets["firewall"])
  log_retention_days = 30
  rule_order         = "DEFAULT_ACTION_ORDER"
  
  # Enable test blocking rules
  enable_test_block_rules = true  # <-- Add this line
  
  tags = merge(var.tags, {
    Purpose = "internet-egress-inspection"
    VPC     = "egress"
  })
  
  depends_on = [module.egress_vpc]
}
```

### For Inspection VPC (East-West Traffic Inspection)

Edit `modules/account-tf-wrapper/network-inspection/network-firewall.tf`:

```terraform
module "network_firewall" {
  count  = local.enable_network_firewall ? 1 : 0
  source = "../../network-firewall"
  
  providers = {
    aws = aws.security
  }
  
  name_prefix        = local.name_prefix
  vpc_id             = module.inspection_vpc.vpc_id
  subnet_ids         = values(module.inspection_vpc.subnets["inspection"])
  log_retention_days = 30
  rule_order         = "DEFAULT_ACTION_ORDER"
  
  # Enable test blocking rules
  enable_test_block_rules = true  # <-- Add this line
  
  tags = merge(var.tags, {
    Purpose = "east-west-inspection"
    VPC     = "inspection"
  })
  
  depends_on = [module.inspection_vpc]
}
```

## Deploy the Changes

### Egress VPC (Network Account)
```bash
cd modules/account-tf-wrapper/network-egress
terraform plan -out=tfplan
terraform apply tfplan
```

### Inspection VPC (Security Account)
```bash
cd modules/account-tf-wrapper/network-inspection
terraform plan -out=tfplan
terraform apply tfplan
```

## Testing the Firewall

### Test 1: Block Google DNS (8.8.8.8)

From an EC2 instance in the Application VPC:

```bash
# This should timeout (blocked by firewall)
ping 8.8.8.8

# This should work (not blocked)
ping 1.1.1.1
```

### Test 2: Block Domains

From an EC2 instance in the Application VPC:

```bash
# These should be blocked
curl -I https://www.facebook.com
curl -I https://www.twitter.com
curl -I https://www.instagram.com

# This should work
curl -I https://www.google.com
```

### Test 3: Block SSH Port (22)

From an EC2 instance in the Application VPC:

```bash
# This should timeout (blocked by firewall)
telnet example.com 22

# This should work
telnet example.com 443
```

## Verify in CloudWatch Logs

Check the Network Firewall logs to see blocked traffic:

### Egress VPC Logs
```bash
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --profile [PROFILE_NAME] \
  --follow \
  --format short
```

### Inspection VPC Logs
```bash
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_INSPECTION] \
  --profile [PROFILE_NAME] \
  --follow \
  --format short
```

Look for log entries with:
- `event_type: DROP` - Traffic was blocked
- `event_type: ALERT` - Traffic matched a rule
- Destination IPs: 8.8.8.8, 8.8.4.4
- Destination domains: facebook.com, twitter.com, instagram.com

## Disable Test Rules

Once testing is complete, remove the `enable_test_block_rules = true` line (or set it to `false`) and re-apply:

```bash
# Remove or set to false
enable_test_block_rules = false

# Apply changes
terraform plan -out=tfplan
terraform apply tfplan
```

## Current Status

-  Egress VPC Network Firewall: **DEPLOYED** (inspecting internet traffic)
-  Test blocking rules: **AVAILABLE** (disabled by default)
-  Inspection VPC Network Firewall: **OPTIONAL** (for east-west traffic)

## Notes

- Test rules are disabled by default (`enable_test_block_rules = false`)
- When enabled, blocking rules take precedence over allow-all rules
- Rule order is `DEFAULT_ACTION_ORDER` (drop rules evaluated before pass rules)
- All traffic is logged to CloudWatch for verification
- Test rules use minimal capacity (100 per rule group)
