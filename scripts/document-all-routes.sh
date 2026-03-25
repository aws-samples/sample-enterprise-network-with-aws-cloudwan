#!/bin/bash
# Document all route tables across all accounts for future reference

OUTPUT_FILE="route-tables-snapshot-$(date +%Y%m%d-%H%M%S).txt"

echo "=========================================="
echo "Route Tables Documentation"
echo "Generated: $(date)"
echo "=========================================="
echo ""

export AWS_REGION=us-east-1

# Function to get route table details
get_route_tables() {
    local profile=$1
    local account_name=$2
    
    echo "=========================================="
    echo "Account: $account_name (Profile: $profile)"
    echo "=========================================="
    echo ""
    
    export AWS_PROFILE=$profile
    
    # Get all VPCs
    vpcs=$(aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0],CidrBlock]' --output text)
    
    while IFS=$'\t' read -r vpc_id vpc_name vpc_cidr; do
        echo "VPC: $vpc_name ($vpc_id) - $vpc_cidr"
        echo "----------------------------------------"
        
        # Get all route tables for this VPC
        route_tables=$(aws ec2 describe-route-tables \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
            --output text)
        
        while IFS=$'\t' read -r rt_id rt_name; do
            echo ""
            echo "  Route Table: $rt_name ($rt_id)"
            
            # Get subnet associations
            subnets=$(aws ec2 describe-route-tables \
                --route-table-ids "$rt_id" \
                --query 'RouteTables[0].Associations[?SubnetId!=`null`].SubnetId' \
                --output text)
            
            if [ -n "$subnets" ]; then
                echo "  Associated Subnets:"
                for subnet in $subnets; do
                    subnet_name=$(aws ec2 describe-subnets \
                        --subnet-ids "$subnet" \
                        --query 'Subnets[0].Tags[?Key==`Name`].Value|[0]' \
                        --output text)
                    echo "    - $subnet_name ($subnet)"
                done
            fi
            
            echo "  Routes:"
            
            # Get routes with all possible target types
            aws ec2 describe-route-tables \
                --route-table-ids "$rt_id" \
                --query 'RouteTables[0].Routes[*].[DestinationCidrBlock,GatewayId,NatGatewayId,TransitGatewayId,VpcPeeringConnectionId,NetworkInterfaceId,VpcEndpointId,CoreNetworkArn,State,Origin]' \
                --output text | while IFS=$'\t' read -r dest gw nat tgw peer eni vpce core_net state origin; do
                
                # Determine target
                target="local"
                if [ "$gw" != "None" ] && [ "$gw" != "" ]; then
                    if [[ "$gw" == igw-* ]]; then
                        target="IGW: $gw"
                    else
                        target="$gw"
                    fi
                elif [ "$nat" != "None" ] && [ "$nat" != "" ]; then
                    target="NAT: $nat"
                elif [ "$tgw" != "None" ] && [ "$tgw" != "" ]; then
                    target="TGW: $tgw"
                elif [ "$peer" != "None" ] && [ "$peer" != "" ]; then
                    target="Peer: $peer"
                elif [ "$eni" != "None" ] && [ "$eni" != "" ]; then
                    target="ENI: $eni"
                elif [ "$vpce" != "None" ] && [ "$vpce" != "" ]; then
                    # Get GWLB endpoint service name if available
                    vpce_type=$(aws ec2 describe-vpc-endpoints \
                        --vpc-endpoint-ids "$vpce" \
                        --query 'VpcEndpoints[0].VpcEndpointType' \
                        --output text 2>/dev/null)
                    target="VPC Endpoint ($vpce_type): $vpce"
                elif [ "$core_net" != "None" ] && [ "$core_net" != "" ]; then
                    core_net_id=$(echo "$core_net" | awk -F'/' '{print $NF}')
                    target="CloudWAN: $core_net_id"
                fi
                
                echo "    $dest -> $target [$state, $origin]"
            done
            
            echo ""
        done <<< "$route_tables"
        
        echo ""
    done <<< "$vpcs"
}

# Document all accounts
{
    echo "=========================================="
    echo "COMPLETE ROUTE TABLES SNAPSHOT"
    echo "=========================================="
    echo ""
    
    get_route_tables "application" "Application Account"
    echo ""
    echo ""
    
    get_route_tables "security" "Security/Inspection Account"
    echo ""
    echo ""
    
    get_route_tables "network" "Network/Egress Account"
    echo ""
    echo ""
    
    echo "=========================================="
    echo "CloudWAN Attachments"
    echo "=========================================="
    export AWS_PROFILE=network
    CORE_NETWORK_ID=$(aws ssm get-parameter --name /aft/network/core-network-id --query 'Parameter.Value' --output text 2>/dev/null || echo "core-network-09e997f508b4a4d1b")
    
    echo "Core Network ID: $CORE_NETWORK_ID"
    echo ""
    
    aws networkmanager list-attachments \
        --core-network-id "$CORE_NETWORK_ID" \
        --query 'Attachments[?AttachmentType==`VPC`].[AttachmentId,State,SegmentName,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    
    echo ""
    echo "=========================================="
    echo "Documentation Complete"
    echo "=========================================="
    
} | tee "$OUTPUT_FILE"

echo ""
echo "Results saved to: $OUTPUT_FILE"
