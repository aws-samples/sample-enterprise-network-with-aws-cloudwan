# CloudWAN Policy Configuration - Service Insertion with Network Function Groups

## Overview

This CloudWAN policy implements **Service Insertion** using Network Function Groups (NFGs) to route traffic through inspection VPCs with AWS Network Firewall for centralized security and internet egress.

## Architecture Flow

### Internet-Bound Traffic (send-to action)

```
Application VPC (Production Segment)
         ↓
    CloudWAN
         ↓
Egress VPC (EgressInspectionVpcs NFG)
         ↓
AWS Network Firewall
         ↓
    NAT Gateway
         ↓
     Internet
```

### East-West Inspection (send-via dual-hop)

```
Development Segment
         ↓
    CloudWAN
         ↓
Inspection VPC (InspectionVpcs NFG)
         ↓
AWS Network Firewall
         ↓
    CloudWAN
         ↓
Production Segment
```

## Policy Components

### 1. Network Segments

| Segment | Purpose | VPCs | Require Acceptance |
|---------|---------|------|-------------------|
| **production** | Production workloads | Application VPC | false |
| **development** | Development workloads | (Future) | false |
| **staging** | Staging workloads | (Future) | false |
| **sandbox** | Sandbox/testing | (Future) | false |
| **egress** | Internet egress | Egress VPC | false |
| **inspection** | East-west inspection | Inspection VPC | false |
| **sharedservices** | DNS, endpoints | Core VPC | false |
| **ingress** | Internet ingress | (Future) | false |

### 2. Network Function Groups (NFGs)

**EgressInspectionVpcs**:
- **Purpose**: Routes all internet-bound traffic through Egress VPC
- **Contains**: Egress VPC attachment
- **Assignment**: VPCs tagged with `nfg=egressinspection`
- **Also assigned to**: `egress` segment (dual assignment)

**InspectionVpcs**:
- **Purpose**: Routes east-west traffic for inspection
- **Contains**: Inspection VPC attachment
- **Assignment**: VPCs tagged with `nfg=inspection`
- **Also assigned to**: `inspection` segment (dual assignment)

### 3. Attachment Policies

Maps VPC attachments to segments and NFGs based on tags:

```hcl
# Rule 100: Assign to InspectionVpcs NFG
Condition: nfg=inspection
Action: add-to-network-function-group = "InspectionVpcs"

# Rule 200: Assign to EgressInspectionVpcs NFG
Condition: nfg=egressinspection
Action: add-to-network-function-group = "EgressInspectionVpcs"

# Rule 300: Assign to segment based on tag
Condition: segment tag exists
Action: association-method = tag, tag-value-of-key = "segment"
```

**Example VPC Tags**:
```
Application VPC:
  segment = "production"
  (no nfg tag - not in any NFG)

Egress VPC:
  segment = "egress"
  nfg = "egressinspection"
  (assigned to both egress segment AND EgressInspectionVpcs NFG)

Inspection VPC:
  segment = "inspection"
  nfg = "inspection"
  (assigned to both inspection segment AND InspectionVpcs NFG)
```

### 4. Segment Actions (The Routing Logic)

#### Action 1-2: Segment Sharing
```hcl
# SharedServices shares with all workload segments
{
  action = "share"
  mode = "attachment-route"
  segment = "sharedservices"
  share-with = ["production", "development", "staging", "sandbox"]
}

# Ingress shares with all segments
{
  action = "share"
  mode = "attachment-route"
  segment = "ingress"
  share-with = ["production", "development", "staging", "sandbox", "sharedservices"]
}
```

#### Action 3-6: All Workload Segments → Internet via EgressInspectionVpcs (send-to)
```hcl
# Production traffic goes directly via EgressInspectionVpcs NFG
{
  action = "send-to"
  segment = "production"
  via = {
    network-function-groups = ["EgressInspectionVpcs"]
  }
}

# Development traffic goes directly via EgressInspectionVpcs NFG
{
  action = "send-to"
  segment = "development"
  via = {
    network-function-groups = ["EgressInspectionVpcs"]
  }
}

# Same for staging and sandbox segments
```

**What this does:**
- All traffic from workload segments (production, development, staging, sandbox) goes directly through EgressInspectionVpcs NFG
- This routes traffic to Egress VPC with Network Firewall
- Provides single-firewall inspection for internet-bound traffic
- **No `when-sent-to` parameter** - applies to ALL traffic from these segments

#### Action 7-9: Development/Staging/Sandbox → Production via InspectionVpcs (send-via)
```hcl
# Development → Production goes via InspectionVpcs NFG
{
  action = "send-via"
  mode = "dual-hop"
  segment = "development"
  via = {
    network-function-groups = ["InspectionVpcs"]
  }
  when-sent-to = {
    segments = ["production"]
  }
}

# Same for staging and sandbox
```

**What this does:**
- When development/staging/sandbox sends traffic specifically to production segment
- CloudWAN routes it through InspectionVpcs NFG first (Inspection VPC)
- Then continues to production segment
- Provides east-west inspection (dev → prod) only

## Traffic Flow Examples

### Example 1: Production Instance → Internet

1. **Production instance** (10.72.0.44) sends packet to www.google.com
2. **Application VPC route table**: 0.0.0.0/0 → CloudWAN
3. **CloudWAN Production Segment**: Matches "send-to" rule → routes via EgressInspectionVpcs NFG
4. **Egress VPC Transit Subnet**: Packet arrives from CloudWAN
5. **Transit Subnet Route**: 0.0.0.0/0 → Network Firewall Endpoint
6. **Network Firewall (Egress VPC)**: Inspects packet, applies rules
7. **Firewall Subnet**: Routes to NAT Gateway
8. **NAT Gateway**: Translates source IP and sends to IGW
9. **Internet Gateway**: Sends to internet
10. **Return traffic**: Follows same path in reverse

**Note**: Production → Internet goes through SINGLE firewall (Egress VPC only)

### Example 2: Development → Production (East-West)

1. **Development VPC** sends packet to production instance (10.72.0.44)
2. **CloudWAN Development Segment**: Matches "send-via" rule (when-sent-to production) → routes via InspectionVpcs NFG
3. **Inspection VPC**: Packet arrives at transit subnet
4. **Transit Subnet Route**: 10.0.0.0/8 → Network Firewall Endpoint
5. **Network Firewall**: Inspects packet
6. **Inspection Subnet**: Routes back to CloudWAN
7. **CloudWAN**: Routes to Production segment
8. **Production VPC**: Receives packet
9. **Return traffic**: Direct route back (no inspection on return)

### Example 3: Development → Internet

1. **Development instance** sends packet to www.google.com
2. **Development VPC route table**: 0.0.0.0/0 → CloudWAN
3. **CloudWAN Development Segment**: Matches "send-to" rule → routes via EgressInspectionVpcs NFG
4. **Egress VPC**: Inspects packet via Network Firewall
5. **NAT Gateway**: Translates and sends to internet

**Note**: Development → Internet goes through SINGLE firewall (Egress VPC only)

### Example 4: Application Instance → Shared Services

1. **Application instance** sends packet to DNS resolver (10.128.0.10)
2. **Application VPC route table**: 10.0.0.0/8 → CloudWAN
3. **CloudWAN Production Segment**: Routes directly to SharedServices (segment sharing)
4. **SharedServices VPC**: Receives packet
5. **Return traffic**: Direct route back

**Note**: No inspection for shared services traffic (direct routing)

## Key Configuration Points

### Dual Assignment (Segment + NFG)

**Egress VPC**:
- Segment: `egress` (allows it to receive traffic as a destination)
- NFG: `EgressInspectionVpcs` (allows it to inspect traffic passing through)

**Inspection VPC**:
- Segment: `inspection` (allows it to receive traffic as a destination)
- NFG: `InspectionVpcs` (allows it to inspect east-west traffic)

### Why send-to is Used for Workload Segments

The `send-to` action on workload segments (production, development, staging, sandbox) means:
- **All traffic from these segments** goes through EgressInspectionVpcs NFG
- This provides single-firewall inspection for internet-bound traffic
- Simple and efficient - no dual-hop required for internet traffic
- Works because Egress VPC is assigned to both egress segment AND EgressInspectionVpcs NFG

### Why send-via is Used for East-West Traffic

The `send-via` action with `when-sent-to = ["production"]` means:
- **Only traffic destined for production segment** goes through InspectionVpcs NFG
- This provides inspection for dev/staging/sandbox → production traffic
- Creates a dual-hop inspection path: Development → Inspection VPC → Production
- Internet traffic bypasses Inspection VPC (goes directly via EgressInspectionVpcs)

### Why send-via Needs when-sent-to

The `send-via` action requires `when-sent-to` to specify:
- **Which destination segments** trigger the inspection
- In our case: development/staging/sandbox → production only
- Without it, CloudWAN doesn't know when to insert the inspection hop

## Route Tables After Policy Application

### Production Segment (Application VPC)
```
Destination         Next Hop
-----------         --------
10.72.0.0/24        Local (Application VPC)
10.128.0.0/22       SharedServices (shared)
0.0.0.0/0           CloudWAN → EgressInspectionVpcs NFG → Internet
```

### Development Segment (Development VPC)
```
Destination         Next Hop
-----------         --------
10.72.1.0/24        Local (Development VPC)
10.128.0.0/22       SharedServices (shared)
10.72.0.0/24        CloudWAN → InspectionVpcs NFG → Production
0.0.0.0/0           CloudWAN → EgressInspectionVpcs NFG → Internet
```

### Egress Segment (Egress VPC)
```
Destination         Next Hop
-----------         --------
10.128.12.0/22      Local (Egress VPC)
10.128.0.0/22       SharedServices (shared)
0.0.0.0/0           NAT Gateway → Internet
```

### Inspection Segment (Inspection VPC)
```
Destination         Next Hop
-----------         --------
10.128.8.0/22       Local (Inspection VPC)
10.72.0.0/24        CloudWAN → Production
10.128.0.0/22       SharedServices (shared)
```

## Verification Commands

### Check Policy Version
```bash
aws networkmanager get-core-network-policy \
  --core-network-id core-network-01e9e6a45c6735eaf \
  --region us-east-1 \
  --query 'CoreNetworkPolicy.PolicyVersionId'
```

### Check Attachments and Segments
```bash
aws networkmanager list-attachments \
  --core-network-id core-network-01e9e6a45c6735eaf \
  --region us-east-1 \
  --query 'Attachments[?State==`AVAILABLE`].[AttachmentId,SegmentName,ResourceArn]' \
  --output table
```

Expected output:
- Application VPC: SegmentName = "production", no NFG
- Egress VPC: SegmentName = "egress", in EgressInspectionVpcs NFG
- Inspection VPC: SegmentName = "inspection", in InspectionVpcs NFG

### Verify Network Function Groups
```bash
aws networkmanager get-core-network-policy \
  --core-network-id core-network-01e9e6a45c6735eaf \
  --region us-east-1 \
  --output json | jq -r '.PolicyDocument' | jq '.["network-function-groups"]'
```

## Deployment Steps

### 1. Update VPC Tags

**Egress VPC** (`modules/account-tf-wrapper/network-egress/main.tf`):
```hcl
tags = {
  segment = "egress"
  nfg = "egressinspection"
}
```

**Inspection VPC** (`modules/account-tf-wrapper/network-inspection/main.tf`):
```hcl
tags = {
  segment = "inspection"
  nfg = "inspection"
}
```

### 2. Deploy Updated CloudWAN Policy
```bash
cd modules/account-tf-wrapper/network-core
terraform plan
terraform apply
```

**Wait 2-3 minutes** for policy to propagate.

### 3. Verify Attachments
```bash
aws networkmanager list-attachments \
  --core-network-id core-network-01e9e6a45c6735eaf \
  --region us-east-1
```

### 4. Test Connectivity
```bash
# From Application VPC instance
ping 10.128.12.1  # Egress VPC
curl -I https://www.google.com  # Internet via Egress VPC
```

## Troubleshooting

### Issue: Traffic not going through Egress VPC

**Check:**
```bash
# Verify Egress VPC has both segment and NFG tags
aws ec2 describe-vpcs --vpc-ids vpc-0070d5117c61bfd60 \
  --query 'Vpcs[0].Tags[?Key==`segment` || Key==`nfg`]'
```

Should show:
- segment = egress
- nfg = egressinspection

### Issue: Policy update fails

**Common causes:**
- Attachment doesn't exist yet
- Segment name mismatch
- NFG referenced before it's defined

**Fix:** Deploy in order:
1. CloudWAN policy (creates NFGs and segments)
2. VPCs with proper tags
3. Wait for attachments to be AVAILABLE
4. Policy will automatically apply

### Issue: Asymmetric routing

**Symptom:** Outbound works, return traffic fails

**Fix:** Ensure segment sharing is configured:
- SharedServices shares with all workload segments
- Ingress shares with all segments

## Best Practices

1. **Always use NFGs for service insertion** - Don't rely on static routes alone
2. **Dual assignment for inspection VPCs** - Assign to both segment AND NFG
3. **Use send-to for internet traffic** - Simple and effective
4. **Use send-via for east-west** - Provides inspection between segments
5. **Wait for policy propagation** - Allow 2-3 minutes after policy changes
6. **Monitor CloudWatch metrics** - Track Network Firewall health and traffic flow

## References

- [AWS CloudWAN Service Insertion](https://docs.aws.amazon.com/vpc/latest/cloudwan/cloudwan-service-insertion.html)
- [Network Function Groups](https://docs.aws.amazon.com/vpc/latest/cloudwan/cloudwan-network-function-groups.html)
- [CloudWAN Policy Documentation](https://docs.aws.amazon.com/vpc/latest/cloudwan/cloudwan-policy-change-sets.html)
- [AWS Network Firewall](https://docs.aws.amazon.com/network-firewall/)
