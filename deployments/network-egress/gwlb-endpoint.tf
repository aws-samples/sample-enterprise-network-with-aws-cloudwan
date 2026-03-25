# GWLB Endpoints for consuming centralized security services
# Only read SSM parameter if GWLB endpoints are enabled
data "aws_ssm_parameter" "checkpoint_service_name" {
  count    = var.egress_config.gwlb_endpoints.checkpoint.enabled ? 1 : 0
  provider = aws.security
  name     = "/aft/network/inspection/gwlb/endpoint-service-name"
}

# CheckPoint GWLB Endpoint in Egress VPC
# Create one endpoint per firewall subnet (one per AZ)
# Note: Only create in AZs where GWLB has subnets (typically first 2 AZs)
resource "aws_vpc_endpoint" "checkpoint_gwlb" {
  for_each = var.egress_config.gwlb_endpoints.checkpoint.enabled ? {
    for idx, az in slice(var.availability_zones, 0, 2) : # Only first 2 AZs
    az => values(module.egress_vpc.subnets["firewall"])[idx]
  } : {}

  provider          = aws.network-services
  vpc_id            = module.egress_vpc.vpc_id
  service_name      = data.aws_ssm_parameter.checkpoint_service_name[0].value
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [each.value] # Only one subnet per GWLB endpoint

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-gwlb-endpoint-${each.key}"
    Environment = var.environment
    Purpose     = "checkpoint-inspection"
    AZ          = each.key
  })
}

# Note: Route table updates are done manually after GWLB endpoint creation
# This is because each firewall subnet may have its own route table
# Run the update script after terraform apply to configure routes

# Store GWLB endpoint IDs for reference
resource "aws_ssm_parameter" "gwlb_endpoint_ids" {
  for_each = var.egress_config.gwlb_endpoints.checkpoint.enabled ? aws_vpc_endpoint.checkpoint_gwlb : {}

  provider = aws.network-services

  name        = "/aft/network/egress/gwlb-endpoint-id-${each.key}"
  description = "GWLB Endpoint ID for egress routing in ${each.key}"
  type        = "String"
  value       = each.value.id

  tags = merge(var.tags, {
    AZ = each.key
  })
}

# Zscaler GWLB Endpoint in Egress VPC (DISABLED)
# module "zscaler_gwlb_endpoint" {
#   count  = var.egress_config.gwlb_endpoints.zscaler.enabled ? 1 : 0
#   source = "../../modules/endpoints"
# 
#   depends_on = [module.egress_vpc]
# 
#   providers = {
#     aws = aws.network-services  # Deploy in network services account
#   }
# 
#   region            = var.primary_region
#   vpc_id            = module.egress_vpc.vpc_id
#   subnet_ids        = {}  # Not used for GWLB endpoints
#   route_table_ids   = []  # Not used for GWLB endpoints
#   endpoint_services = []  # Not creating AWS service endpoints
#   security_group_id = ""  # Not used for GWLB endpoints
# 
#   # GWLB endpoint configuration - read service name from security account
#   gwlb_endpoints = [
#     {
#       name               = "${local.name_prefix}-zscaler-gwlb-endpoint"
#       service_name       = data.aws_ssm_parameter.zscaler_service_name.value
#       ssm_parameter_name = null  # Use direct service name
#       subnet_ids         = [values(module.egress_vpc.subnets["proxy"])[0]]  # Only one subnet for GWLB
#     }
#   ]
# 
#   tags = merge(var.tags, {
#     Name        = "${local.name_prefix}-zscaler-gwlb-endpoint"
#     Environment = var.environment
#     Purpose     = "zscaler-inspection"
#   })
# }