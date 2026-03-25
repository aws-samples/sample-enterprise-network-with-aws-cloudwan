# AWS CloudWAN Network Routing Guide

## Overview

This document provides a comprehensive guide to all routes created in the AWS CloudWAN with Network Firewall Service Insertion architecture. It explains what routes are created, where they're created, their purpose, and how they enable traffic flow.

---

## Visual Reference

### Traffic Flow Diagrams

For visual understanding of routing patterns, refer to:
- **[North-South Traffic](architecture-diagrams/north-south-traffic.png)** - Internet egress routing
- **[East-West Traffic](architecture-diagrams/east-west-traffic.png)** - Inter-segment routing
- **[Core Network](architecture-diagrams/core-network.png)** - Complete network topology

---

## Table of Contents

1. [Route Types Overview](#route-types-overview)
2. [VPC Module Routes](#vpc-module-routes)
3. [Network Firewall Module Routes](#network-firewall-module-routes)
4. [Deployment-Specific Routes](#deployment-specific-routes)
5. [Route Tables by VPC](#route-tables-by-vpc)
6. [Traffic Flow Examples](#traffic-flow-examples)
7. [Troubleshooting](#troubleshooting)

---

## Route Types Overview

### Route Categories

| Category | Created By | Purpose | Count |
|----------|-----------|---------|-------|
| **Local Routes** | AWS (automatic) | Intra-VPC communication | 1 per VPC |
| **Internet Gateway Routes** | VPC Module | Internet access | 1 per public subnet |
| **NAT Gateway Routes** | VPC Module | Private subnet internet access | 1 per private subnet |
| **CloudWAN Routes** | VPC Module | Inter-VPC communication | 2-3 per VPC |
| **Network Firewall Routes** | Network Firewall Module | Traffic inspection | 3-5 per firewall |
| **Return Routes** | Deployment-specific | Asymmetric routing fix | 3 per egress VPC |

---

## VPC Module Routes

The VPC module (`modules/vpc/`) automatically creates routes based on configuration.

### 1. Internet Gateway Routes

**Created For**: Public subnets  
**Destination**: `0.0.0.0/0`  
**Target**: Internet Gateway  
**Purpose**: Allow public subnets to reach the internet

**Configuration**:
```terraform
vpc_configuration = {
  features = {
    create_igw = true
  }
  subnet_configuration = {
    public = {
      route_table_config = {
        routes = [{
          destination = "0.0.0.0/0"
          target_type = "internet_gateway"
          target_id   = "igw-placeholder"
        }]
      }
    }
  }
}
```

**VPCs Using This**:
- network-egress (public subnets)
- workload-production (public subnets for CloudFront)

**Traffic Flow**:
```
Public Subnet → Internet Gateway → Internet
```

---

### 2. NAT Gateway Routes

**Created For**: Private subnets needing internet access  
**Destination**: `0.0.0.0/0`  
**Target**: NAT Gateway  
**Purpose**: Allow private subnets to reach internet (outbound only)

**Configuration**:
```terraform
vpc_configuration = {
  features = {
    enable_nat_gateway = true
  }
  subnet_configuration = {
    firewall = {
      route_table_config = {
        routes = [{
          destination = "0.0.0.0/0"
          target_type = "nat_gateway"
          target_id   = "nat-placeholder"
        }]
      }
    }
  }
}
```

**VPCs Using This**:
- network-egress (firewall subnets)

**Traffic Flow**:
```
Firewall Subnet → NAT Gateway → Internet Gateway → Internet
```

---

### 3. CloudWAN Routes

**Created For**: All subnets needing inter-VPC communication  
**Destination**: Various (10.0.0.0/8, 0.0.0.0/0, specific VPC CIDRs)  
**Target**: CloudWAN Core Network ARN  
**Purpose**: Enable communication between VPCs via CloudWAN

**Configuration**:
```terraform
cloudwan_routes = {
  private  = ["10.0.0.0/8", "0.0.0.0/0"]
  database = ["10.0.0.0/8"]
  transit  = ["10.0.0.0/8", "0.0.0.0/0"]
}
```

**Module Implementation** (`modules/vpc/routes.tf`):
```terraform
resource "aws_route" "cloudwan" {
  for_each = local.cloudwan_routes_map

  route_table_id         = local.route_tables[each.value.subnet_type].id
  destination_cidr_block = each.value.cidr
  core_network_arn       = each.value.core_network_arn

  depends_on = [
    aws_networkmanager_vpc_attachment.main,
    aws_route_table_association.main
  ]
}
```

**VPCs Using This**:
- network-egress (transit, firewall subnets)
- network-inspection (transit, inspection, management subnets)
- workload-production (private, database subnets)
- workload-development (private, database subnets)

**Traffic Flow**:
```
Workload VPC → CloudWAN → Egress VPC → Internet
Workload VPC → CloudWAN → Inspection VPC → CloudWAN → Destination
```

---

## Network Firewall Module Routes

The Network Firewall module (`modules/network-firewall/`) creates routes for traffic inspection.

### 1. Transit Subnet → Firewall Routes

**Created For**: Transit subnets (CloudWAN attachment subnets)  
**Destination**: `0.0.0.0/0` (all traffic)  
**Target**: Network Firewall Endpoint  
**Purpose**: Force all traffic through firewall for inspection

**Configuration**:
```terraform
module "network_firewall" {
  manage_routes = true
  transit_routes = {
    default = "0.0.0.0/0"
  }
}
```

**Module Implementation** (`modules/network-firewall/routes.tf`):
```terraform
resource "aws_route" "transit_to_firewall" {
  for_each = var.manage_routes ? var.transit_routes : {}
  
  route_table_id         = var.route_table_ids.transit
  destination_cidr_block = each.value
  vpc_endpoint_id        = local.firewall_endpoint_ids[0]
}
```

**VPCs Using This**:
- network-egress (transit → firewall)
- network-inspection (transit → firewall)

**Traffic Flow**:
```
CloudWAN → Transit Subnet → Network Firewall → Firewall Subnet
```

---

### 2. Firewall Subnet → NAT/CloudWAN Routes

**Created For**: Firewall subnets (where firewall endpoints are)  
**Destination**: `0.0.0.0/0` (internet) or `10.0.0.0/8` (internal)  
**Target**: NAT Gateway (egress) or CloudWAN (inspection)  
**Purpose**: Route inspected traffic to destination

**Configuration**:
```terraform
module "network_firewall" {
  manage_routes = true
  firewall_routes = {
    internet = "0.0.0.0/0"
    internal = "10.0.0.0/8"
  }
  nat_gateway_id = module.vpc.nat_gateway_ids[0]
}
```

**Module Implementation** (`modules/network-firewall/routes.tf`):
```terraform
resource "aws_route" "firewall_to_nat" {
  for_each = var.manage_routes && var.nat_gateway_id != null ? {
    for k, v in var.firewall_routes : k => v
    if v == "0.0.0.0/0"
  } : {}
  
  route_table_id         = var.route_table_ids.firewall
  destination_cidr_block = each.value
  nat_gateway_id         = var.nat_gateway_id
}

resource "aws_route" "firewall_to_cloudwan" {
  for_each = var.manage_routes && var.core_network_arn != null ? {
    for k, v in var.firewall_routes : k => v
    if v != "0.0.0.0/0"
  } : {}
  
  route_table_id         = var.route_table_ids.firewall
  destination_cidr_block = each.value
  core_network_arn       = var.core_network_arn
}
```

**VPCs Using This**:
- network-egress (firewall → NAT for internet, firewall → CloudWAN for internal)
- network-inspection (firewall → CloudWAN for all traffic)

**Traffic Flow**:
```
# Egress VPC
Network Firewall → Firewall Subnet → NAT Gateway → Internet (0.0.0.0/0)
Network Firewall → Firewall Subnet → CloudWAN → Workload VPCs (10.0.0.0/8)

# Inspection VPC
Network Firewall → Firewall Subnet → CloudWAN → Destination
```

---

### 3. Public Subnet Return Routes

**Created For**: Public subnets in egress VPC  
**Destination**: Internal CIDR ranges (10.0.0.0/8, specific VPC CIDRs)  
**Target**: Network Firewall Endpoint  
**Purpose**: Fix asymmetric routing for return traffic

**Configuration**:
```terraform
module "network_firewall" {
  manage_routes = true
  public_return_routes = {
    internal = "10.0.0.0/8"
    app_vpc  = "10.72.0.0/24"
    dev_vpc  = "10.72.1.0/24"
  }
}
```

**Module Implementation** (`modules/network-firewall/routes.tf`):
```terraform
resource "aws_route" "public_return" {
  for_each = var.manage_routes ? var.public_return_routes : {}
  
  route_table_id         = var.route_table_ids.public
  destination_cidr_block = each.value
  vpc_endpoint_id        = local.firewall_endpoint_ids[0]
}
```

**VPCs Using This**:
- network-egress (public subnets)

**Why This Is Critical**:
AWS Support identified that return traffic was bypassing the firewall, causing:
- `app_proto: "unknown"` in flow logs (no bidirectional visibility)
- Domain-based rules not matching (Layer 7 inspection requires both directions)

**Traffic Flow**:
```
# Forward Path
App VPC → CloudWAN → Transit Subnet → NFW → Firewall Subnet → NAT GW → Public Subnet → Internet

# Return Path (WITH fix)
Internet → Public Subnet → NFW → Transit Subnet → CloudWAN → App VPC

# Return Path (WITHOUT fix - BROKEN)
Internet → Public Subnet → CloudWAN → App VPC (bypasses firewall!)
```

---

## Deployment-Specific Routes

Some routes are created directly in deployment files because they're highly specific.

### 1. Network Firewall Return Routes (Egress VPC)

**Location**: `deployments/network-egress/main.tf`  
**Created For**: Public subnets  
**Purpose**: Asymmetric routing fix for specific workload VPCs

```terraform
resource "aws_route" "public_to_firewall_internal" {
  count                  = local.enable_network_firewall ? 1 : 0
  route_table_id         = local.public_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  vpc_endpoint_id        = local.firewall_endpoint_id
}

resource "aws_route" "public_to_firewall_app_vpc" {
  count                  = local.enable_network_firewall ? 1 : 0
  route_table_id         = local.public_route_table_id
  destination_cidr_block = "10.72.0.0/24"  # Production VPC
  vpc_endpoint_id        = local.firewall_endpoint_id
}

resource "aws_route" "public_to_firewall_dev_vpc" {
  count                  = local.enable_network_firewall ? 1 : 0
  route_table_id         = local.public_route_table_id
  destination_cidr_block = "10.72.1.0/24"  # Development VPC
  vpc_endpoint_id        = local.firewall_endpoint_id
}
```

**Why Deployment-Specific**:
- References specific workload VPC CIDRs
- Part of AWS Support-recommended asymmetric routing fix
- Highly specific to egress VPC architecture

---

## Route Tables by VPC

### Network Core VPC

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| **Transit** | Local | Local | Intra-VPC |
| **Private** | Local | Local | Intra-VPC |
| **Endpoints** | Local | Local | Intra-VPC |

**Notes**: 
- Core VPC uses CloudWAN for all inter-VPC routing
- No explicit routes needed (CloudWAN manages routing)

---

### Network Egress VPC

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| **Public** | Local | Local | Intra-VPC |
| **Public** | 0.0.0.0/0 | IGW | Internet access |
| **Public** | 10.0.0.0/8 | NFW Endpoint | Return traffic inspection |
| **Public** | 10.72.0.0/24 | NFW Endpoint | App VPC return traffic |
| **Public** | 10.72.1.0/24 | NFW Endpoint | Dev VPC return traffic |
| **Firewall** | Local | Local | Intra-VPC |
| **Firewall** | 0.0.0.0/0 | NAT Gateway | Internet via NAT |
| **Firewall** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Transit** | Local | Local | Intra-VPC |
| **Transit** | 0.0.0.0/0 | NFW Endpoint | All traffic to firewall |
| **Transit** | 10.0.0.0/8 | CloudWAN | Internal networks |

**Traffic Flow**:
```
Workload → CloudWAN → Transit → NFW → Firewall → NAT → Public → IGW → Internet
Internet → Public → NFW → Transit → CloudWAN → Workload
```

---

### Network Inspection VPC

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| **Transit** | Local | Local | Intra-VPC |
| **Transit** | 10.72.0.0/24 | CloudWAN | App VPC |
| **Transit** | 10.0.0.0/8 | CloudWAN | All internal |
| **Transit** | 0.0.0.0/0 | CloudWAN | Default route |
| **Inspection** | Local | Local | Intra-VPC |
| **Inspection** | 10.0.0.0/8 | CloudWAN | Internal VPCs |
| **Inspection** | 0.0.0.0/0 | CloudWAN | Forward to egress |
| **Management** | Local | Local | Intra-VPC |
| **Management** | 10.0.0.0/8 | CloudWAN | Access from VPCs |

**Traffic Flow**:
```
VPC A → CloudWAN → Transit → NFW → Inspection → CloudWAN → VPC B
```

---

### Workload Production VPC

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| **Private** | Local | Local | Intra-VPC |
| **Private** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Private** | 0.0.0.0/0 | CloudWAN | Internet via egress |
| **Database** | Local | Local | Intra-VPC |
| **Database** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Transit** | Local | Local | Intra-VPC |
| **Transit** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Transit** | 0.0.0.0/0 | CloudWAN | Internet via egress |

**Traffic Flow**:
```
App Instance → Private Subnet → CloudWAN → Egress VPC → Internet
App Instance → Private Subnet → CloudWAN → Other VPCs
```

---

### Workload Development VPC

| Route Table | Destination | Target | Purpose |
|-------------|-------------|--------|---------|
| **Private** | Local | Local | Intra-VPC |
| **Private** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Database** | Local | Local | Intra-VPC |
| **Database** | 10.0.0.0/8 | CloudWAN | Internal networks |
| **Transit** | Local | Local | Intra-VPC |
| **Transit** | 10.0.0.0/8 | CloudWAN | Internal networks |

**Traffic Flow**:
```
Dev Instance → Private Subnet → CloudWAN → Inspection VPC → CloudWAN → Production VPC
Dev Instance → Private Subnet → CloudWAN → Egress VPC → Internet
```

---

## Traffic Flow Examples

### Example 1: Production App → Internet

```
1. App Instance (10.72.0.10) → Private Subnet Route Table
   └─ Destination: 0.0.0.0/0 → Target: CloudWAN

2. CloudWAN → Egress VPC (based on segment policy)
   └─ Arrives at: Transit Subnet

3. Transit Subnet Route Table
   └─ Destination: 0.0.0.0/0 → Target: Network Firewall Endpoint

4. Network Firewall → Inspects traffic → Allows/Denies

5. Firewall Subnet Route Table
   └─ Destination: 0.0.0.0/0 → Target: NAT Gateway

6. NAT Gateway → Translates source IP

7. Public Subnet Route Table
   └─ Destination: 0.0.0.0/0 → Target: Internet Gateway

8. Internet Gateway → Internet

RETURN PATH:
Internet → IGW → Public Subnet → NFW (via return route) → Transit → CloudWAN → App
```

---

### Example 2: Development → Production (East-West)

```
1. Dev Instance (10.72.1.10) → Private Subnet Route Table
   └─ Destination: 10.72.0.0/24 → Target: CloudWAN

2. CloudWAN → Inspection VPC (based on segment policy - send-via)
   └─ Arrives at: Transit Subnet

3. Transit Subnet Route Table
   └─ Destination: 10.72.0.0/24 → Target: CloudWAN (or NFW if enabled)

4. Network Firewall (if enabled) → Inspects traffic

5. CloudWAN → Production VPC
   └─ Arrives at: Transit Subnet

6. Transit Subnet → Private Subnet (local routing)

7. Production Instance receives traffic

RETURN PATH:
Production → CloudWAN → Inspection VPC → CloudWAN → Development
```

---

### Example 3: Production → Shared Services (Core VPC)

```
1. App Instance (10.72.0.10) → Private Subnet Route Table
   └─ Destination: 10.0.0.0/8 → Target: CloudWAN

2. CloudWAN → Core VPC (based on segment policy)
   └─ Arrives at: Transit Subnet

3. Transit Subnet → Private Subnet (local routing)

4. VPC Endpoint or Shared Service receives traffic

RETURN PATH:
Core VPC → CloudWAN → Production VPC (direct, no inspection)
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Traffic Not Reaching Internet

**Symptoms**:
- Instances can't reach internet
- Timeouts on outbound connections

**Check**:
1. Verify CloudWAN route exists in private subnet: `10.0.0.0/8` or `0.0.0.0/0` → CloudWAN
2. Verify transit subnet route: `0.0.0.0/0` → Network Firewall
3. Verify firewall subnet route: `0.0.0.0/0` → NAT Gateway
4. Verify public subnet route: `0.0.0.0/0` → Internet Gateway
5. Check Network Firewall rules allow traffic
6. Verify NAT Gateway is healthy

**Commands**:
```bash
# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxxxx"

# Check Network Firewall
aws network-firewall describe-firewall --firewall-name xxx

# Check NAT Gateway
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx
```

---

#### Issue 2: East-West Traffic Not Working

**Symptoms**:
- Can't reach other VPCs
- Timeouts on internal connections

**Check**:
1. Verify CloudWAN route exists: `10.0.0.0/8` → CloudWAN
2. Verify CloudWAN attachment is active
3. Check CloudWAN policy allows traffic between segments
4. Verify Network Firewall rules (if inspection enabled)

**Commands**:
```bash
# Check CloudWAN attachments
aws networkmanager list-attachments --core-network-id xxx

# Check CloudWAN policy
aws networkmanager get-core-network-policy --core-network-id xxx
```

---

#### Issue 3: Asymmetric Routing (app_proto: unknown)

**Symptoms**:
- Flow logs show `app_proto: "unknown"`
- Domain-based firewall rules not working
- Layer 7 inspection failing

**Root Cause**:
Return traffic bypassing Network Firewall

**Fix**:
Ensure public subnet return routes exist:
```terraform
resource "aws_route" "public_to_firewall_internal" {
  route_table_id         = public_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  vpc_endpoint_id        = firewall_endpoint_id
}
```

**Verify**:
```bash
# Check public subnet route table
aws ec2 describe-route-tables --route-table-ids rtb-xxxxx

# Should see route: 10.0.0.0/8 → vpce-xxxxx (firewall endpoint)
```

---

#### Issue 4: Routes Not Created by Module

**Symptoms**:
- Expected routes missing
- Terraform plan shows no routes

**Check**:
1. Verify `cloudwan_routes` variable is set
2. Verify `manage_routes = true` for Network Firewall
3. Check CloudWAN attachment is created first
4. Verify route table IDs are correct

**Debug**:
```bash
# Check Terraform state
terraform state list | grep aws_route

# Check module outputs
terraform output -module=vpc
```

---

## Route Creation Summary

### By Module

| Module | Route Types | Count | Automatic |
|--------|-------------|-------|-----------|
| **VPC Module** | IGW, NAT, CloudWAN | 5-10 per VPC | Yes |
| **Network Firewall Module** | Transit→FW, FW→NAT/CloudWAN, Public Return | 3-5 per firewall | Yes |
| **Deployments** | Specific return routes | 3 per egress | Manual |

### Total Routes Created

| VPC | Route Tables | Routes per Table | Total Routes |
|-----|--------------|------------------|--------------|
| **network-core** | 3 | 1-2 | 5 |
| **network-egress** | 3 | 3-5 | 12 |
| **network-inspection** | 3 | 2-4 | 9 |
| **workload-production** | 3 | 2-3 | 8 |
| **workload-development** | 3 | 1-2 | 6 |
| **TOTAL** | **15** | - | **40** |

---

## Best Practices

### 1. Route Organization
- Use modules for reusable route patterns  
- Keep deployment-specific routes in deployments  
- Document route purpose in comments  
- Use consistent naming conventions  

### 2. Route Management
- Let modules handle dependencies  
- Use `depends_on` for explicit ordering  
- Avoid circular dependencies  
- Test route changes in non-production first  

### 3. Troubleshooting
- Check routes in order (source → destination)  
- Verify each hop in the path  
- Use VPC Flow Logs for debugging  
- Check Network Firewall logs for denials  

### 4. Documentation
- Document custom routes  
- Explain why routes are needed  
- Keep routing guide updated  
- Include traffic flow diagrams  

---

## Conclusion

This routing architecture provides:
- **Centralized Internet Egress**: All internet traffic through egress VPC
- **Traffic Inspection**: Network Firewall inspects all traffic
- **Segmentation**: CloudWAN segments isolate environments
- **Flexibility**: Easy to add new VPCs and routes
- **Security**: All traffic inspected and logged

The modular approach ensures:
- **Consistency**: All VPCs use same routing patterns
- **Maintainability**: Routes managed in modules
- **Scalability**: Easy to add new deployments
- **Reliability**: Automatic dependency management

---

*Last Updated: [Current Date]*  
*Version: 1.0*  
*Status: Production*
