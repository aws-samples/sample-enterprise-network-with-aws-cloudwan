#!/bin/bash

# Deployment Values Configuration Template
# Copy this file to deployment-values.sh and fill in your actual values
# DO NOT commit deployment-values.sh to git (it's in .gitignore)

# AWS Account IDs
export NETWORK_CORE_ACCOUNT_ID="123456789012"      # Your Network Core/Services account
export SECURITY_ACCOUNT_ID="234567890123"          # Your Security/Inspection account  
export APPLICATION_ACCOUNT_ID="345678901234"       # Your Application/Workload account
export SHARED_SERVICES_ACCOUNT_ID="456789012345"   # Your Shared Services account (for Terraform state)

# VPC CIDR Blocks
export CORE_VPC_CIDR="10.128.0.0/22"               # Core VPC CIDR (1024 IPs)
export EGRESS_VPC_CIDR="10.128.12.0/22"            # Egress VPC CIDR (1024 IPs)
export INSPECTION_VPC_CIDR="10.128.8.0/22"         # Inspection VPC CIDR (1024 IPs)
export INGRESS_VPC_CIDR="10.128.4.0/22"            # Ingress VPC CIDR (1024 IPs)
export PRODUCTION_VPC_CIDR="10.72.0.0/24"          # Production workload VPC (256 IPs)
export DEVELOPMENT_VPC_CIDR="10.72.1.0/24"         # Development workload VPC (256 IPs)
export ORGANIZATION_CIDR="10.0.0.0/8"              # Organization-wide CIDR

# AWS Regions
export PRIMARY_REGION="us-east-1"                  # Primary deployment region
export SECONDARY_REGION="us-west-2"                # Secondary region (if multi-region)

# Instance IPs (examples - these will be assigned by AWS)
export PROD_INSTANCE_IP_1="10.72.0.16"             # First production instance
export PROD_INSTANCE_IP_2="10.72.0.53"             # Second production instance
export DEV_INSTANCE_IP="10.72.1.11"                # Development instance

# CloudWAN Configuration
export CORE_NETWORK_ID=""                          # Will be created during deployment
export CORE_NETWORK_ARN=""                         # Will be created during deployment

# Environment
export ENVIRONMENT="enterprise"                     # Your environment name
export PROJECT_NAME="network-infrastructure"        # Your project name

# Terraform State Configuration
export TF_STATE_BUCKET="terraform-state-network-${SHARED_SERVICES_ACCOUNT_ID}"
export TF_STATE_DYNAMODB_TABLE="terraform-state-locks"
export TF_STATE_REGION="${PRIMARY_REGION}"

# Helper function to validate configuration
validate_config() {
    echo "Validating configuration..."
    
    # Check if account IDs are still default values
    if [ "$NETWORK_CORE_ACCOUNT_ID" = "123456789012" ]; then
        echo "⚠️  WARNING: NETWORK_CORE_ACCOUNT_ID is still the default value"
        echo "   Please update with your actual account ID"
        return 1
    fi
    
    if [ "$SECURITY_ACCOUNT_ID" = "234567890123" ]; then
        echo "⚠️  WARNING: SECURITY_ACCOUNT_ID is still the default value"
        echo "   Please update with your actual account ID"
        return 1
    fi
    
    if [ "$APPLICATION_ACCOUNT_ID" = "345678901234" ]; then
        echo "⚠️  WARNING: APPLICATION_ACCOUNT_ID is still the default value"
        echo "   Please update with your actual account ID"
        return 1
    fi
    
    echo "✅ Configuration looks good!"
    return 0
}

# Display current configuration
show_config() {
    echo "Current Configuration:"
    echo "====================="
    echo ""
    echo "AWS Accounts:"
    echo "  Network Core:    $NETWORK_CORE_ACCOUNT_ID"
    echo "  Security:        $SECURITY_ACCOUNT_ID"
    echo "  Application:     $APPLICATION_ACCOUNT_ID"
    echo "  Shared Services: $SHARED_SERVICES_ACCOUNT_ID"
    echo ""
    echo "VPC CIDRs:"
    echo "  Core:        $CORE_VPC_CIDR"
    echo "  Egress:      $EGRESS_VPC_CIDR"
    echo "  Inspection:  $INSPECTION_VPC_CIDR"
    echo "  Ingress:     $INGRESS_VPC_CIDR"
    echo "  Production:  $PRODUCTION_VPC_CIDR"
    echo "  Development: $DEVELOPMENT_VPC_CIDR"
    echo ""
    echo "Regions:"
    echo "  Primary:   $PRIMARY_REGION"
    echo "  Secondary: $SECONDARY_REGION"
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo "Project:     $PROJECT_NAME"
    echo ""
}

# If sourced, show config
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    show_config
    validate_config
fi
