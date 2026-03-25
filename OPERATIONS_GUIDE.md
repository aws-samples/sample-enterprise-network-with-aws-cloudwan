# Operations Guide - AWS CloudWAN Network Architecture

## Overview

This guide provides Standard Operating Procedures (SOPs) for managing and operating the AWS CloudWAN network architecture.

## Table of Contents

1. [Adding New VPCs to Segments](#adding-new-vpcs-to-segments)
2. [Configuring Routes for New VPCs](#configuring-routes-for-new-vpcs)
3. [Managing Network Firewall Rules](#managing-network-firewall-rules)
4. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
5. [Cost Optimization](#cost-optimization)

---

## Adding New VPCs to Segments

### Prerequisites

- AWS CLI configured with appropriate profiles
- Terraform installed (version 1.5.0 or higher)
- Access to Network Services account for IPAM pool information
- Understanding of CloudWAN segments (production, development, staging, etc.)

### Procedure

#### Step 1: Determine Target Segment

Choose the appropriate segment for your new VPC:

- **production**: Production workloads requiring internet access and east-west inspection
- **development**: Development workloads with limited internet access
- **staging**: Pre-production testing environments
- **sandbox**: Experimental workloads with isolated access
- **sharedservices**: Shared infrastructure (DNS, endpoints, etc.)

#### Step 2: Create VPC Configuration File

Create a new directory for your VPC:

```bash
mkdir -p deployments/my-new-vpc
cd deployments/my-new-vpc
```

Create `terraform.tfvars`:

```hcl
# Basic Configuration
environment        = "enterprise"
region            = "us-east-1"
primary_region    = "us-east-1"
is_primary_region = true
enabled_regions   = ["us-east-1"]

# Availability Zones
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Account Configuration
network_core_account_id     = "[NETWORK_SERVICES_ACCOUNT_ID]"
network_services_account_id = "[NETWORK_SERVICES_ACCOUNT_ID]"
security_account_id         = "[SECURITY_ACCOUNT_ID]"
management_account_id       = "[MANAGEMENT_ACCOUNT_ID]"

# VPC Configuration
vpc_netmask_length = 24  # /24 = 256 IPs

subnet_netmasks = {
  private  = 26  # /26 = 64 IPs per AZ
  database = 27  # /27 = 32 IPs per AZ
  transit  = 28  # /28 = 16 IPs per AZ
}

# Tags
tags = {
  Project     = "enterprise-network"
  Environment = "production"
  Segment     = "production"
  ManagedBy   = "terraform"
  Owner       = "your-team"
}
```

#### Step 3: Deploy the VPC

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=vpc.tfplan

# Apply
terraform apply vpc.tfplan
```

#### Step 4: Verify Deployment

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Segment,Values=production" \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check CloudWAN attachment
export AWS_PROFILE=network
aws networkmanager list-attachments \
  --core-network-id $CORE_NETWORK_ID \
  --region us-east-1 \
  --query 'Attachments[?State==`AVAILABLE`].[AttachmentId,SegmentName]' \
  --output table
```

---

## Configuring Routes for New VPCs

### Understanding Route Configuration

CloudWAN automatically handles routing between segments based on the policy. However, you need to configure routes within your VPC to direct traffic to CloudWAN.

### Standard Route Configuration

#### For Workload VPCs (Production, Development, Staging)

All workload VPCs should have these routes in their private subnets:

```hcl
routes = [
  # Local VPC traffic
  {
    destination = local.vpc_cidr
    target_type = "local"
    target_id   = ""
  },
  # Internet traffic via CloudWAN → Egress VPC
  {
    destination = "0.0.0.0/0"
    target_type = "cloudwan"
    target_id   = local.core_network_id
  },
  # Internal traffic via CloudWAN
  {
    destination = "10.0.0.0/8"
    target_type = "cloudwan"
    target_id   = local.core_network_id
  }
]
```

#### For Transit Subnets (CloudWAN Attachment)

Transit subnets are where CloudWAN attaches to your VPC. They need the same routes as private subnets.

### Route Configuration Examples

#### Example 1: Application VPC with Internet Access

```hcl
subnet_configuration = {
  private = {
    type               = "private"
    cidr_blocks        = ["10.72.0.0/26", "10.72.0.64/26", "10.72.0.128/26"]
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    route_table_config = {
      routes = [
        {
          destination = "10.72.0.0/24"  # Local VPC
          target_type = "local"
          target_id   = ""
        },
        {
          destination = "0.0.0.0/0"  # Internet via CloudWAN
          target_type = "cloudwan"
          target_id   = local.core_network_id
        },
        {
          destination = "10.0.0.0/8"  # Internal VPCs via CloudWAN
          target_type = "cloudwan"
          target_id   = local.core_network_id
        }
      ]
    }
  }
}
```

#### Example 2: Development VPC without Internet Access

```hcl
subnet_configuration = {
  private = {
    type               = "private"
    cidr_blocks        = ["10.72.1.0/26", "10.72.1.64/26", "10.72.1.128/26"]
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
    route_table_config = {
      routes = [
        {
          destination = "10.72.1.0/24"  # Local VPC
          target_type = "local"
          target_id   = ""
        },
        {
          destination = "10.0.0.0/8"  # Internal VPCs only
          target_type = "cloudwan"
          target_id   = local.core_network_id
        }
        # NO 0.0.0.0/0 route = no internet access
      ]
    }
  }
}
```

### Modifying Routes After Deployment

If you need to add or modify routes after deployment:

```bash
# Get route table ID
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=YOUR_VPC_ID" "Name=tag:Name,Values=*private*" \
  --query 'RouteTables[0].RouteTableId' \
  --output text \
  --region us-east-1)

# Add new route
aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 172.16.0.0/12 \
  --core-network-arn arn:aws:networkmanager:us-east-1:[ACCOUNT_ID]:core-network/$CORE_NETWORK_ID \
  --region us-east-1
```

Or update via Terraform:

```hcl
# Add to your route_table_config
{
  destination = "172.16.0.0/12"
  target_type = "cloudwan"
  target_id   = local.core_network_id
}
```

---

## Managing Network Firewall Rules

### Current Firewall Configuration

You have two Network Firewalls deployed:

1. **Egress VPC Firewall**: Inspects internet-bound traffic
2. **Inspection VPC Firewall**: Inspects east-west traffic between segments

### Adding Custom Blocking Rules

#### Step 1: Edit Firewall Configuration

For Egress VPC firewall:

```bash
cd deployments/network-egress
vi network-firewall.tf
```

For Inspection VPC firewall:

```bash
cd deployments/network-inspection
vi network-firewall.tf
```

#### Step 2: Add Custom Rules

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  custom_block_rules = [
    {
      name        = "block-specific-ip"
      source      = "10.72.1.0/24"  # Development VPC
      destination = "10.72.0.53/32"  # Specific production IP
      description = "Block Dev to specific Prod IP"
    },
    {
      name        = "block-another-ip"
      source      = "10.72.1.0/24"
      destination = "8.8.8.8/32"  # Block Google DNS
      description = "Block access to Google DNS"
    }
  ]
}
```

#### Step 3: Apply Changes

```bash
terraform plan
terraform apply
```

### Adding AWS Managed Rule Groups

AWS provides managed rule groups for common threats:

```hcl
module "network_firewall" {
  source = "../../modules/network-firewall"
  
  custom_rule_group_arns = [
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/AbusedLegitMalwareDomainsActionOrder",
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/ThreatSignaturesMalwareActionOrder",
    "arn:aws:network-firewall:us-east-1:aws-managed:stateful-rulegroup/BotNetCommandAndControlDomainsActionOrder"
  ]
}
```

---

## Monitoring and Troubleshooting

### CloudWatch Metrics

**Network Firewall**:
- `PacketsDropped`: Packets blocked by rules
- `PacketsForwarded`: Packets allowed through
- `InvalidDroppedPackets`: Malformed packets

**CloudWAN**:
- `BytesIn/BytesOut`: Traffic volume
- `PacketsIn/PacketsOut`: Packet count
- `AttachmentState`: Attachment health

**NAT Gateway**:
- `BytesOutToDestination`: Egress traffic
- `BytesInFromSource`: Ingress traffic
- `ErrorPortAllocation`: Port exhaustion

### Logs

**Network Firewall Logs**:
```bash
aws logs tail /aws/network-firewall/egress-firewall --follow --region us-east-1
aws logs tail /aws/network-firewall/inspection-firewall --follow --region us-east-1
```

**VPC Flow Logs**:
```bash
aws logs tail /aws/vpc/flowlogs --follow --region us-east-1
```

### Troubleshooting

#### Issue: No Internet Connectivity

**Check 1**: Verify Egress VPC is deployed
```bash
export AWS_PROFILE=network
aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --region us-east-1
```

**Check 2**: Verify Network Firewall is healthy
```bash
aws network-firewall list-firewalls --region us-east-1
```

**Check 3**: Verify CloudWAN attachments
```bash
aws networkmanager list-attachments \
  --core-network-id $CORE_NETWORK_ID \
  --region us-east-1 \
  --query 'Attachments[?State!=`AVAILABLE`]'
```

#### Issue: East-West Traffic Not Working

**Check 1**: Verify Inspection VPC firewall is deployed
```bash
export AWS_PROFILE=security
aws network-firewall list-firewalls --region us-east-1
```

**Check 2**: Verify security groups allow traffic
```bash
export AWS_PROFILE=application
aws ec2 describe-security-groups \
  --filters "Name=tag:Segment,Values=production" \
  --query 'SecurityGroups[].IpPermissions[]' \
  --region us-east-1
```

---

## Cost Optimization

### Single Firewall Deployment

Deploy only Egress VPC firewall to save ~$865/month:

```hcl
# In network-inspection/terraform.tfvars
enable_network_firewall = false
```

### Reduce to 2 AZs

Deploy in 2 AZs instead of 3 to save ~$580/month per firewall:

```hcl
# In terraform.tfvars
availability_zones = ["us-east-1a", "us-east-1b"]
```

### Smaller Instance Types

Use t3.micro for dev/test to save ~$10/month per instance:

```hcl
# In workload-development/terraform.tfvars
instance_config = {
  count         = 1
  instance_type = "t3.micro"
}
```

---

**Last Updated**: 2026

