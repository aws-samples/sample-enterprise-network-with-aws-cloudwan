# Customer Setup Guide - AWS CloudWAN Network Architecture

## Overview

This guide helps you customize the generic AWS CloudWAN Network Architecture template for your specific environment.

---

## Step 1: Gather Your Information

Before starting, collect the following information about your AWS environment:

### AWS Accounts

```
Network Services Account ID:    ___________________
Security Account ID:            ___________________
Application Account ID:         ___________________
Management Account ID:          ___________________
```

### Network Configuration

```
Primary Region:                 ___________________
Availability Zones:             ___________________
Organization CIDR Block:        ___________________
Network Services CIDR:          ___________________
Workload CIDR:                  ___________________
```

### Firewall Configuration

```
Enable Egress Firewall:         Yes / No
Enable Inspection Firewall:     Yes / No
Enable AWS Managed Rules:       Yes / No
Custom Firewall Rules:          ___________________
```

---

## Step 2: Replace Placeholders

### 2.1 Account IDs

Replace all account ID placeholders in `terraform.tfvars` files:

```bash
# Replace in all terraform.tfvars files
find deployments -name "terraform.tfvars" -exec sed -i \
  's/\[NETWORK_SERVICES_ACCOUNT_ID\]/YOUR_NETWORK_ACCOUNT_ID/g' {} \;

find deployments -name "terraform.tfvars" -exec sed -i \
  's/\[SECURITY_ACCOUNT_ID\]/YOUR_SECURITY_ACCOUNT_ID/g' {} \;

find deployments -name "terraform.tfvars" -exec sed -i \
  's/\[APPLICATION_ACCOUNT_ID\]/YOUR_APPLICATION_ACCOUNT_ID/g' {} \;

find deployments -name "terraform.tfvars" -exec sed -i \
  's/\[MANAGEMENT_ACCOUNT_ID\]/YOUR_MANAGEMENT_ACCOUNT_ID/g' {} \;
```

### 2.2 Network Configuration

Edit each `terraform.tfvars` file and update:

```hcl
# deployments/network-core/terraform.tfvars
region            = "us-east-1"  # Change to your region
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  # Your AZs

pool_configuration = {
  pool_cidrs = {
    global_cidr   = "10.0.0.0/8"      # Your organization CIDR
    core_cidr     = "10.64.0.0/16"    # Your core CIDR
    network_cidr  = "10.128.0.0/14"   # Your network CIDR
    workload_cidr = "10.72.0.0/14"    # Your workload CIDR
    # ... update other CIDRs as needed
  }
}
```

### 2.3 Firewall Configuration

Edit firewall configuration files:

```hcl
# deployments/network-egress/terraform.tfvars
enable_network_firewall = true  # Set to false to disable

# deployments/network-inspection/terraform.tfvars
enable_network_firewall = true  # Set to false to disable
```

---

## Step 3: Configure AWS CLI Profiles

Set up AWS CLI profiles for each account:

```bash
# ~/.aws/config
[profile network]
region = us-east-1
role_arn = arn:aws:iam::YOUR_NETWORK_ACCOUNT_ID:role/TerraformRole
source_profile = default

[profile security]
region = us-east-1
role_arn = arn:aws:iam::YOUR_SECURITY_ACCOUNT_ID:role/TerraformRole
source_profile = default

[profile application]
region = us-east-1
role_arn = arn:aws:iam::YOUR_APPLICATION_ACCOUNT_ID:role/TerraformRole
source_profile = default
```

---

## Step 4: Customize Network Configuration

### 4.1 CIDR Blocks

Update CIDR blocks based on your organization's IP allocation:

```hcl
# Example: If your organization uses 172.16.0.0/12
pool_configuration = {
  pool_cidrs = {
    global_cidr   = "172.16.0.0/12"
    core_cidr     = "172.16.0.0/16"
    network_cidr  = "172.17.0.0/16"
    workload_cidr = "172.18.0.0/16"
  }
}
```

### 4.2 Availability Zones

Adjust availability zones based on your region:

```hcl
# For us-west-2
availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

# For eu-west-1
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
```

### 4.3 Instance Types

Customize EC2 instance types:

```hcl
# deployments/workload-production/terraform.tfvars
instance_config = {
  count         = 2
  instance_type = "t3.medium"  # Change from t3.small
}

# deployments/workload-development/terraform.tfvars
instance_config = {
  count         = 1
  instance_type = "t3.micro"  # Smaller for development
}
```

---

## Step 5: Customize Firewall Rules

### 5.1 Add Custom Blocking Rules

Edit `deployments/network-inspection/network-firewall.tf`:

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  custom_block_rules = [
    {
      name        = "block-dev-to-prod"
      source      = "10.72.1.0/24"  # Your dev CIDR
      destination = "10.72.0.0/24"  # Your prod CIDR
      description = "Block dev to prod traffic"
    },
    {
      name        = "block-malicious-ip"
      source      = "ANY"
      destination = "203.0.113.0/24"  # Malicious IP range
      description = "Block known malicious IPs"
    }
  ]
}
```

### 5.2 Enable AWS Managed Rules

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  custom_rule_group_arns = [
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/AbusedLegitMalwareDomainsActionOrder",
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatSignaturesMalwareActionOrder"
  ]
}
```

---

## Step 6: Customize Tags

Update tags in all `terraform.tfvars` files:

```hcl
tags = {
  Project     = "your-project-name"
  Environment = "production"
  CostCenter  = "your-cost-center"
  Owner       = "your-team"
  ManagedBy   = "terraform"
}
```

---

## Step 7: Validate Configuration

Before deploying, validate your configuration:

```bash
# Check for syntax errors
cd deployments/network-core
terraform init
terraform validate

# Review the plan
terraform plan -out=tfplan

# Check for any issues
terraform show tfplan | grep -i error
```

---

## Step 8: Deploy Infrastructure

Follow the deployment order from `DEPLOYMENT_GUIDE.md`:

```bash
# Phase 1: Network Core
export AWS_PROFILE=network
cd deployments/network-core
terraform apply

# Phase 2: Egress VPC
cd ../network-egress
terraform apply

# Phase 3: Inspection VPC
export AWS_PROFILE=security
cd ../network-inspection
terraform apply

# Phase 4: Application VPC
export AWS_PROFILE=application
cd ../workload-production
terraform apply

# Phase 5: Development VPC
cd ../workload-development
terraform apply
```

---

## Step 9: Verify Deployment

Verify all components are deployed correctly:

```bash
# Check CloudWAN
export AWS_PROFILE=network
CORE_NETWORK_ID=$(aws networkmanager list-core-networks \
  --region us-east-1 \
  --query 'CoreNetworks[0].CoreNetworkId' \
  --output text)

aws networkmanager get-core-network \
  --core-network-id $CORE_NETWORK_ID \
  --region us-east-1

# Check VPCs
aws ec2 describe-vpcs \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check Network Firewalls
aws network-firewall list-firewalls \
  --region us-east-1 \
  --query 'Firewalls[].[Name,FirewallStatus]' \
  --output table
```

---

## Step 10: Post-Deployment Configuration

### 10.1 Configure Monitoring

Set up CloudWatch alarms for:
- Network Firewall dropped packets
- NAT Gateway port exhaustion
- CloudWAN attachment state changes

### 10.2 Configure Logging

Enable logging for:
- Network Firewall logs
- VPC Flow Logs
- CloudWAN logs

### 10.3 Document Your Configuration

Create a configuration document for your team:

```markdown
# Network Configuration

## Accounts
- Network Services: [ACCOUNT_ID]
- Security: [ACCOUNT_ID]
- Application: [ACCOUNT_ID]

## Network
- Organization CIDR: 10.0.0.0/8
- Network Services CIDR: 10.128.0.0/14
- Workload CIDR: 10.72.0.0/14

## Firewalls
- Egress Firewall: Enabled
- Inspection Firewall: Enabled
- AWS Managed Rules: Enabled

## Custom Rules
- Block dev to prod: Enabled
- Block malicious IPs: Enabled
```

---

## Troubleshooting

### Issue: Terraform Plan Fails

**Check 1**: Verify AWS credentials
```bash
aws sts get-caller-identity --profile network
```

**Check 2**: Verify account IDs are correct
```bash
grep "ACCOUNT_ID" deployments/*/terraform.tfvars
```

**Check 3**: Verify CIDR blocks don't overlap
```bash
# Check for overlapping CIDRs
grep "cidr" deployments/*/terraform.tfvars | sort
```

### Issue: Deployment Fails

**Check 1**: Verify IAM permissions
```bash
aws iam list-attached-role-policies --role-name TerraformRole
```

**Check 2**: Check CloudFormation events
```bash
aws cloudformation describe-stack-events \
  --stack-name cloudwan-network-core \
  --region us-east-1
```

### Issue: No Internet Connectivity

**Check 1**: Verify NAT Gateways are deployed
```bash
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

**Check 2**: Verify Network Firewall is healthy
```bash
aws network-firewall describe-firewall --firewall-name egress-firewall
```

---

## Next Steps

1. ✅ Customize configuration for your environment
2. ✅ Deploy infrastructure
3. ✅ Verify all components
4. ✅ Configure monitoring and logging
5. ✅ Test traffic flows
6. ✅ Document your configuration
7. ✅ Train your team on operations

---

## Support

For questions or issues, refer to:
- `DEPLOYMENT_GUIDE.md` - Deployment procedures
- `OPERATIONS_GUIDE.md` - Operations procedures
- `COMPLETE_SOLUTION_OVERVIEW.md` - Architecture details
- AWS CloudWAN documentation: https://docs.aws.amazon.com/vpc/latest/cloudwan/

---

**Last Updated**: 2026

