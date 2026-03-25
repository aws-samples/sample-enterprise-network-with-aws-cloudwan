# Traffic Flow Verification - Network Firewall Inspection

## Overview

This guide verifies that traffic flows correctly through Network Firewall in both Egress and Inspection VPCs before reaching its destination.

## Architecture Diagrams

For visual reference of traffic flows:
- **[North-South Traffic](architecture-diagrams/north-south-traffic.png)** - Internet egress inspection
- **[East-West Traffic](architecture-diagrams/east-west-traffic.png)** - Inter-segment inspection
- **[Core Network](architecture-diagrams/core-network.png)** - Complete network topology

---

## Architecture Verification

### Expected Traffic Flows

#### Internet-Bound Traffic (Single Firewall Inspection)
```
Application VPC (10.72.0.0/24)
    ↓ Route: 0.0.0.0/0 → CloudWAN
CloudWAN (Production Segment)
    ↓ send-to action → EgressInspectionVpcs NFG
Egress VPC Transit Subnet (10.128.12.0/26)
    ↓ Route: 0.0.0.0/0 → Network Firewall Endpoint
Network Firewall (Egress VPC - SINGLE INSPECTION)
    ↓ Stateful inspection, log FLOW/ALERT
Egress VPC Firewall Subnet (10.128.12.64/26)
    ↓ Route: 0.0.0.0/0 → NAT Gateway
NAT Gateway (Public Subnet)
    ↓ Source NAT translation
Internet Gateway
    ↓
Internet
```

**Note**: Internet traffic goes through SINGLE firewall (Egress VPC only)

#### East-West Traffic (Inspection VPC)
```
Development VPC
    ↓ Route: 10.72.0.0/24 → CloudWAN
CloudWAN (Development Segment)
    ↓ send-via dual-hop → InspectionVpcs NFG
Inspection VPC Transit Subnet (10.128.8.0/26)
    ↓ Route: 10.0.0.0/8 → Network Firewall Endpoint
Network Firewall (INSPECTION)
    ↓ Stateful inspection, log FLOW/ALERT
Inspection VPC Inspection Subnet (10.128.8.64/26)
    ↓ Route: 10.0.0.0/8 → CloudWAN
CloudWAN
    ↓ Route to destination segment
Application VPC (Application)
```

---

## Step 1: Verify Network Firewall Deployment

### Check Egress VPC Firewall

```bash
export AWS_PROFILE=network

# Check firewall status
aws network-firewall describe-firewall \
  --firewall-name [FIREWALL_NAME_EGRESS] \
  --region [REGION] \
  --query 'Firewall.{Name:FirewallName,Status:FirewallStatus.Status,VpcId:VpcId}' \
  --output table

# Expected: Status = READY

# Check firewall endpoints (should have 3, one per AZ)
aws network-firewall describe-firewall \
  --firewall-name [FIREWALL_NAME_EGRESS] \
  --region [REGION] \
  --query 'FirewallStatus.SyncStates.*.Attachment[0].{SubnetId:SubnetId,EndpointId:EndpointId,Status:Status}' \
  --output table

# Expected: 3 endpoints with Status = READY
```

### Check Inspection VPC Firewall

```bash
export AWS_PROFILE=security

# Check firewall status
aws network-firewall describe-firewall \
  --firewall-name [FIREWALL_NAME_INSPECTION] \
  --region [REGION] \
  --query 'Firewall.{Name:FirewallName,Status:FirewallStatus.Status,VpcId:VpcId}' \
  --output table

# Expected: Status = READY

# Check firewall endpoints
aws network-firewall describe-firewall \
  --firewall-name [FIREWALL_NAME_INSPECTION] \
  --region [REGION] \
  --query 'FirewallStatus.SyncStates.*.Attachment[0].{SubnetId:SubnetId,EndpointId:EndpointId,Status:Status}' \
  --output table

# Expected: 3 endpoints with Status = READY
```

---

## Step 2: Verify Route Tables

### Egress VPC Route Tables

```bash
export AWS_PROFILE=network

# Get Egress VPC ID
EGRESS_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Type,Values=egress" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region us-east-1)

echo "Egress VPC ID: $EGRESS_VPC_ID"

# Get Network Firewall endpoint ID
FIREWALL_ENDPOINT=$(aws network-firewall describe-firewall \
  --firewall-name [FIREWALL_NAME_EGRESS] \
  --region [REGION] \
  --query 'FirewallStatus.SyncStates.*.Attachment[0].EndpointId | [0]' \
  --output text)

echo "Firewall Endpoint: $FIREWALL_ENDPOINT"

# Check Transit Subnet Route Table
echo -e "\n=== TRANSIT SUBNET ROUTES ==="
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$EGRESS_VPC_ID" "Name=tag:Name,Values=*transit*" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,VpcEndpointId]' \
  --region us-east-1 \
  --output table

# Expected routes:
# 10.128.12.0/22  local
# 0.0.0.0/0       vpce-xxx (firewall endpoint)
# 10.0.0.0/8      vpce-xxx (firewall endpoint)

# Check Firewall Subnet Route Table
echo -e "\n=== FIREWALL SUBNET ROUTES ==="
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$EGRESS_VPC_ID" "Name=tag:Name,Values=*firewall*" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,VpcEndpointId,CoreNetworkArn]' \
  --region us-east-1 \
  --output table

# Expected routes:
# 10.128.12.0/22  local
# 0.0.0.0/0       nat-xxx (NAT Gateway)
# 10.0.0.0/8      cloudwan (for return traffic)

# Check Public Subnet Route Table
echo -e "\n=== PUBLIC SUBNET ROUTES ==="
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$EGRESS_VPC_ID" "Name=tag:Name,Values=*public*" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,CoreNetworkArn]' \
  --region us-east-1 \
  --output table

# Expected routes:
# 10.128.12.0/22  local
# 0.0.0.0/0       igw-xxx (Internet Gateway)
# 10.72.0.0/24    cloudwan (return route to Application VPC)
# 10.0.0.0/8      cloudwan
```

### Inspection VPC Route Tables

```bash
export AWS_PROFILE=security

# Get Inspection VPC ID
INSPECTION_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Type,Values=inspection" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region us-east-1)

echo "Inspection VPC ID: $INSPECTION_VPC_ID"

# Check Transit Subnet Route Table
echo -e "\n=== TRANSIT SUBNET ROUTES ==="
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$INSPECTION_VPC_ID" "Name=tag:Name,Values=*transit*" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,VpcEndpointId,CoreNetworkArn]' \
  --region us-east-1 \
  --output table

# Expected routes:
# 10.128.8.0/22   local
# 0.0.0.0/0       vpce-xxx (firewall endpoint)
# 10.0.0.0/8      vpce-xxx (firewall endpoint)

# Check Inspection Subnet Route Table
echo -e "\n=== INSPECTION SUBNET ROUTES ==="
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$INSPECTION_VPC_ID" "Name=tag:Name,Values=*inspection*" \
  --query 'RouteTables[0].Routes[].[DestinationCidrBlock,GatewayId,CoreNetworkArn]' \
  --region us-east-1 \
  --output table

# Expected routes:
# 10.128.8.0/22   local
# 0.0.0.0/0       cloudwan
# 10.0.0.0/8      cloudwan
```

---

## Step 3: Test Internet Connectivity with Firewall Inspection

### Test from Application VPC

```bash
export AWS_PROFILE=application

# Get Application instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" "Name=tag:segment,Values=production" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --region us-east-1)

echo "Instance ID: $INSTANCE_ID"

# Connect to instance
aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

### Inside the Application Instance

```bash
# Test DNS resolution
nslookup google.com

# Test ICMP (ping)
ping -c 4 8.8.8.8

# Test HTTP/HTTPS
curl -I https://www.google.com
curl -I https://www.amazon.com

# Test with verbose output
curl -v https://www.google.com 2>&1 | head -20

# Check if traffic is going through NAT (should see NAT Gateway public IP)
curl -s https://ifconfig.me
```

**Expected Results:**
-  DNS resolution works
-  Ping succeeds (4 packets, 0% loss)
-  HTTP 200 response from websites
-  Public IP matches NAT Gateway Elastic IP

---

## Step 4: Verify Firewall Logs (CRITICAL - Proves Inspection)

### Check Egress VPC Firewall Logs

```bash
export AWS_PROFILE=network

# Tail firewall logs in real-time
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --follow \
  --region [REGION]

# Or get recent logs
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --since 5m \
  --region [REGION] \
  --format short

# Filter for specific traffic
aws logs filter-log-events \
  --log-group-name /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --start-time $(date -u -d '5 minutes ago' +%s)000 \
  --filter-pattern "PASS" \
  --region [REGION] \
  --query 'events[].message' \
  --output text
```

**Expected Log Entries:**
```
event_timestamp="..." src_ip="10.72.0.x" dst_ip="8.8.8.8" action="PASS"
event_timestamp="..." src_ip="10.72.0.x" dst_ip="142.250.x.x" action="PASS"
```

**Key Indicators:**
-  `action="PASS"` - Traffic is being inspected and allowed
-  `src_ip="10.72.0.x"` - Source is Application VPC
-  Logs appear in real-time when you test connectivity

### Check Inspection VPC Firewall Logs

```bash
export AWS_PROFILE=security

# Tail firewall logs
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_INSPECTION] \
  --follow \
  --region [REGION]

# Get recent logs
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_INSPECTION] \
  --since 5m \
  --region [REGION] \
  --format short
```

**Note:** Inspection VPC logs will only show traffic if you have east-west traffic (dev → prod). If only Application VPC is deployed, these logs will be empty.

---

## Step 5: Verify CloudWAN Routing

### Check CloudWAN Attachments

```bash
export AWS_PROFILE=network

# List all attachments
aws networkmanager list-attachments \
  --core-network-id core-network-01e9e6a45c6735eaf \
  --region us-east-1 \
  --query 'Attachments[?State==`AVAILABLE`].[AttachmentId,SegmentName,Tags[?Key==`Name`].Value|[0],Tags[?Key==`nfg`].Value|[0]]' \
  --output table
```

**Expected Output:**
```
---------------------------------------------------------
|                   ListAttachments                     |
+-------------------------------+-------------+---------+
| attachment-006117639f9f5c632 | None        | egress-vpc-attachment | egressinspection |
| attachment-085ede62a86c3f300 | production  | app-vpc-attachment    | (none)           |
| attachment-033f1e3705209d54a | None        | insp-vpc-attachment   | inspection       |
| attachment-02e21fdedc422f0d5 | sharedservices | core-vpc-attachment | (none)         |
+-------------------------------+-------------+---------+
```

**Verification:**
-  Egress VPC: SegmentName = None, NFG = egressinspection
-  Application VPC: SegmentName = production
-  Inspection VPC: SegmentName = None, NFG = inspection

---

## Step 6: Verify VPC Flow Logs

### Check Application VPC Flow Logs

```bash
export AWS_PROFILE=application

# Get flow log group
FLOW_LOG_GROUP=$(aws ec2 describe-flow-logs \
  --region us-east-1 \
  --query 'FlowLogs[0].LogDestination' \
  --output text | cut -d':' -f7)

echo "Flow Log Group: $FLOW_LOG_GROUP"

# Tail flow logs
aws logs tail $FLOW_LOG_GROUP \
  --since 5m \
  --region us-east-1 \
  --format short | grep ACCEPT

# Look for outbound traffic to internet
aws logs filter-log-events \
  --log-group-name $FLOW_LOG_GROUP \
  --start-time $(date -u -d '5 minutes ago' +%s)000 \
  --filter-pattern "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=ACCEPT, flowlogstatus]" \
  --region us-east-1 \
  --query 'events[].message' \
  --output text | head -20
```

**Expected:**
-  ACCEPT records for outbound traffic (source = 10.72.0.x)
-  ACCEPT records for return traffic
-  No REJECT records for internet-bound traffic

---

## Step 7: Performance and Latency Check

### Measure Latency Through Firewall

```bash
# From Application instance
# Test latency to internet
ping -c 10 8.8.8.8

# Expected: ~2-5ms additional latency due to firewall inspection
# Baseline (no firewall): ~1-2ms
# With firewall: ~3-7ms

# Test HTTP response time
time curl -s https://www.google.com > /dev/null

# Expected: < 500ms for first request
```

---

## Step 8: Verify Firewall Metrics

### Check CloudWatch Metrics

```bash
export AWS_PROFILE=network

# Get packets forwarded (should be > 0)
aws cloudwatch get-metric-statistics \
  --namespace AWS/NetworkFirewall \
  --metric-name PacketsForwarded \
  --dimensions Name=FirewallName,Value=[FIREWALL_NAME_EGRESS] \
  --start-time $(date -u -d '10 minutes ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 300 \
  --statistics Sum \
  --region [REGION]

# Get packets dropped (should be 0 with allow-all rule)
aws cloudwatch get-metric-statistics \
  --namespace AWS/NetworkFirewall \
  --metric-name PacketsDropped \
  --dimensions Name=FirewallName,Value=[FIREWALL_NAME_EGRESS] \
  --start-time $(date -u -d '10 minutes ago' --iso-8601=seconds) \
  --end-time $(date -u --iso-8601=seconds) \
  --period 300 \
  --statistics Sum \
  --region [REGION]
```

**Expected:**
-  PacketsForwarded > 0 (traffic is flowing)
-  PacketsDropped = 0 (allow-all rule)

---

## Verification Checklist

### Egress VPC (Internet Traffic)

- [ ] Network Firewall status = READY
- [ ] 3 firewall endpoints deployed (one per AZ)
- [ ] Transit subnet routes 0.0.0.0/0 → Firewall endpoint
- [ ] Firewall subnet routes 0.0.0.0/0 → NAT Gateway
- [ ] Public subnet routes 0.0.0.0/0 → Internet Gateway
- [ ] Application instance can ping 8.8.8.8
- [ ] Application instance can curl https://www.google.com
- [ ] Firewall logs show PASS actions
- [ ] VPC Flow Logs show ACCEPT records
- [ ] CloudWatch metrics show PacketsForwarded > 0

### Inspection VPC (East-West Traffic)

- [ ] Network Firewall status = READY
- [ ] 3 firewall endpoints deployed (one per AZ)
- [ ] Transit subnet routes 10.0.0.0/8 → Firewall endpoint
- [ ] Inspection subnet routes 10.0.0.0/8 → CloudWAN
- [ ] Firewall logs configured (will show traffic when dev→prod deployed)

### CloudWAN

- [ ] Egress VPC in EgressInspectionVpcs NFG
- [ ] Inspection VPC in InspectionVpcs NFG
- [ ] Application VPC in application segment
- [ ] All attachments in AVAILABLE state

---

## Troubleshooting

### Issue: No firewall logs appearing

**Cause:** Traffic not going through firewall

**Check:**
```bash
# Verify transit subnet routes point to firewall
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*transit*" --region us-east-1
```

**Solution:** Ensure routes are created correctly in transit subnets

### Issue: Internet connectivity fails

**Cause:** Firewall or NAT Gateway misconfigured

**Check:**
```bash
# Check firewall status
aws network-firewall describe-firewall --firewall-name [FIREWALL_NAME_EGRESS] --region [REGION]

# Check NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --region [REGION]
```

**Solution:** Verify all components are in READY/available state

### Issue: High latency

**Cause:** Normal firewall inspection overhead

**Expected:** 2-5ms additional latency

**If > 10ms:** Check firewall capacity metrics

---

## Success Criteria

 **All traffic flows through Network Firewall before egress**
 **Firewall logs show inspection activity**
 **Internet connectivity works from Application VPC**
 **No REJECT records in VPC Flow Logs**
 **CloudWatch metrics show active traffic**

---

**Verification Complete!** Your Network Firewall is properly inspecting all traffic before it reaches the internet.
