# Deployment Guide - AWS Enterprise Network Architecture

## Overview

This guide provides complete deployment instructions for the AWS Enterprise Network Architecture with CloudWAN Service Insertion and AWS Network Firewall.

## Prerequisites

### AWS Account Setup

**Required Accounts**:
1. **Network Services Account**
   - CloudWAN, IPAM, DNS
   - Egress VPC with Network Firewall
   - Core VPC (shared services)

2. **Security Account**
   - Inspection VPC with Network Firewall

3. **Application Account**
   - Application workload VPCs
   - EC2 instances

### AWS CLI Profiles

Configure AWS CLI profiles:

```bash
# ~/.aws/config
[profile network]
region = us-east-1

[profile security]
region = us-east-1

[profile application]
region = us-east-1
```

### Terraform Setup

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# Verify version
terraform version  # Should be >= 1.5.0
```

---

## Deployment Order

### Phase 1: Network Core Foundation

**Duration**: ~15 minutes  
**Account**: Network Services

#### What Gets Deployed

- CloudWAN Global Network and Core Network
- CloudWAN Policy with 8 segments and 2 NFGs
- IPAM with organization-wide pool
- DNS resolvers
- Core VPC in sharedservices segment

#### Deployment Commands

```bash
# Set AWS profile
export AWS_PROFILE=network

# Navigate to network-core module
cd deployments/network-core

# Initialize Terraform
terraform init -upgrade

# Review configuration
cat terraform.tfvars

# Plan deployment
terraform plan -out=network-core.tfplan

# Apply
terraform apply network-core.tfplan
```

#### Verification

```bash
# Get Core Network ID
CORE_NETWORK_ID=$(aws networkmanager list-core-networks \
  --region us-east-1 \
  --query 'CoreNetworks[0].CoreNetworkId' \
  --output text)

echo "Core Network ID: $CORE_NETWORK_ID"

# Check Core Network status
aws networkmanager get-core-network \
  --core-network-id $CORE_NETWORK_ID \
  --region us-east-1 \
  --query 'CoreNetwork.{State:State,PolicyVersion:PolicyVersionId}'

# Expected: State=AVAILABLE
```

---

### Phase 2: Egress VPC with Network Firewall

**Duration**: ~20 minutes  
**Account**: Network Services

#### What Gets Deployed

- Egress VPC
  - Public subnets (3 AZs) - NAT Gateways
  - Firewall subnets (3 AZs) - Network Firewall endpoints
  - Transit subnets (3 AZs) - CloudWAN attachment
- AWS Network Firewall (3 AZ endpoints)
- NAT Gateways (3 AZs)
- Internet Gateway
- CloudWAN attachment (egress segment + EgressInspectionVpcs NFG)

#### Deployment Commands

```bash
# Set AWS profile
export AWS_PROFILE=network

# Navigate to network-egress module
cd deployments/network-egress

# Initialize Terraform
terraform init -upgrade

# Review configuration
cat terraform.tfvars

# Plan deployment
terraform plan -out=network-egress.tfplan

# Apply
terraform apply network-egress.tfplan
```

#### Verification

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Type,Values=egress" \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check NAT Gateways
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available" \
  --region us-east-1 \
  --query 'NatGateways[].[NatGatewayId,State,SubnetId,PublicIp]' \
  --output table

# Expected: 3 NAT Gateways in available state

# Check Network Firewall
aws network-firewall list-firewalls \
  --region us-east-1 \
  --query 'Firewalls[].[Name,FirewallStatus]' \
  --output table

# Expected: Firewall in READY status
```

---

### Phase 3: Inspection VPC with Network Firewall

**Duration**: ~20 minutes  
**Account**: Security

#### What Gets Deployed

- Inspection VPC
  - Inspection subnets (3 AZs) - Network Firewall endpoints
  - Transit subnets (3 AZs) - CloudWAN attachment
  - Management subnets (3 AZs) - Operational access
- AWS Network Firewall (3 AZ endpoints)
- CloudWAN attachment (inspection segment + InspectionVpcs NFG)

#### Deployment Commands

```bash
# Set AWS profile
export AWS_PROFILE=security

# Navigate to network-inspection module
cd deployments/network-inspection

# Initialize Terraform
terraform init -upgrade

# Review configuration
cat terraform.tfvars

# Plan deployment
terraform plan -out=network-inspection.tfplan

# Apply
terraform apply network-inspection.tfplan
```

#### Verification

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Type,Values=inspection" \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check Network Firewall
aws network-firewall list-firewalls \
  --region us-east-1 \
  --query 'Firewalls[].[Name,FirewallStatus]' \
  --output table

# Expected: Firewall in READY status
```

---

### Phase 4: Application VPC (Production)

**Duration**: ~15 minutes  
**Account**: Application

#### What Gets Deployed

- Application VPC
  - Private subnets (3 AZs) - EC2 instances
  - Database subnets (3 AZs) - RDS-ready
  - Transit subnets (3 AZs) - CloudWAN attachment
- EC2 instances
- Internal ALB
- VPC Endpoints (S3, SSM, EC2Messages, SSMMessages)
- Security Groups
- CloudWAN attachment (application segment)

#### Deployment Commands

```bash
# Set AWS profile
export AWS_PROFILE=application

# Navigate to application module
cd deployments/workload-production

# Initialize Terraform
terraform init -upgrade

# Review configuration
cat terraform.tfvars

# Plan deployment
terraform plan -out=workload-production.tfplan

# Apply
terraform apply workload-production.tfplan
```

#### Verification

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Segment,Values=production" \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check EC2 instances
aws ec2 describe-instances \
  --filters "Name:instance-state-name,Values=running" \
  --region us-east-1 \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType,State.Name]' \
  --output table

# Expected: Instances running
```

---

### Phase 5: Development VPC

**Duration**: ~15 minutes  
**Account**: Application

#### What Gets Deployed

- Development VPC
  - Private subnets (3 AZs) - EC2 instances
  - Database subnets (3 AZs) - RDS-ready
  - Transit subnets (3 AZs) - CloudWAN attachment
- EC2 instance
- VPC Endpoints (S3, SSM, EC2Messages, SSMMessages)
- Security Groups
- CloudWAN attachment (development segment)
- **NO internet routes** - only internal (10.0.0.0/8)

#### Deployment Commands

```bash
# Set AWS profile
export AWS_PROFILE=application

# Navigate to development module
cd deployments/workload-development

# Initialize Terraform
terraform init -upgrade

# Review configuration
cat terraform.tfvars

# Plan deployment
terraform plan -out=workload-development.tfplan

# Apply
terraform apply workload-development.tfplan
```

#### Verification

```bash
# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Segment,Values=development" \
  --region us-east-1 \
  --query 'Vpcs[].[VpcId,CidrBlock,State]' \
  --output table

# Check EC2 instance
aws ec2 describe-instances \
  --filters "Name=tag:Segment,Values=development" "Name=instance-state-name,Values=running" \
  --region us-east-1 \
  --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType,State.Name]' \
  --output table

# Expected: Instance running
```

---

## Post-Deployment Verification

### Check All CloudWAN Attachments

```bash
export AWS_PROFILE=network

# List all attachments
aws networkmanager list-attachments \
  --core-network-id $CORE_NETWORK_ID \
  --region us-east-1 \
  --query 'Attachments[?State==`AVAILABLE`].[AttachmentId,SegmentName,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### Check Network Firewall Logs

```bash
# Egress firewall logs
aws logs tail /aws/network-firewall/egress-firewall \
  --follow \
  --region us-east-1

# Inspection firewall logs
aws logs tail /aws/network-firewall/inspection-firewall \
  --follow \
  --region us-east-1
```

---

## Destroy Order (Teardown)

If you need to tear down the infrastructure, follow this order (reverse of deployment):

```bash
# Phase 1: Destroy Development VPC
export AWS_PROFILE=application
cd deployments/workload-development
terraform destroy -auto-approve

# Phase 2: Destroy Application VPC
cd ../workload-production
terraform destroy -auto-approve

# Phase 3: Destroy Inspection VPC
export AWS_PROFILE=security
cd ../../deployments/network-inspection
terraform destroy -auto-approve

# Phase 4: Destroy Egress VPC
export AWS_PROFILE=network
cd ../network-egress
terraform destroy -auto-approve

# Phase 5: Destroy Network Core
cd ../network-core
terraform destroy -auto-approve
```

---

## Troubleshooting

### Issue: No Internet Connectivity from Application VPC

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

---

## Deployment Timeline

| Phase | Duration | Total |
|-------|----------|-------|
| Network Core | 15 min | 15 min |
| Egress VPC | 20 min | 20 min |
| Inspection VPC | 20 min | 20 min |
| Application VPC | 15 min | 15 min |
| Development VPC | 15 min | 15 min |
| **Total** | **85 min** | **~1.5 hours** |

---

**Last Updated**: 2026

