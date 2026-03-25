# Gateway Load Balancer for centralized inspection with simple Linux routers
module "gwlb" {
  count  = var.security_config.gwlb.enabled ? 1 : 0
  source = "../../modules/gwlb"

  providers = {
    aws = aws.security
  }

  name_prefix = local.name_prefix
  vpc_id      = module.inspection_vpc.vpc_id
  vpc_cidr    = local.vpc_cidr
  region      = var.region

  # GWLB deployed in inspection subnets
  gwlb_subnet_ids = values(module.inspection_vpc.subnets["inspection"])

  # Router instances in inspection subnets
  router_subnet_ids = values(module.inspection_vpc.subnets["inspection"])

  # GWLB endpoints in management subnets (for CloudWAN traffic)
  gwlb_endpoint_subnets = {
    for az in var.availability_zones :
    az => module.inspection_vpc.subnets["management"][az]
  }

  # Router instance configuration
  ami_id            = data.aws_ami.amazon_linux_2023.id
  instance_type     = try(var.security_config.gwlb.router_config.instance_type, "t3.small")
  min_instances     = try(var.security_config.gwlb.router_config.min_instances, 2)
  max_instances     = try(var.security_config.gwlb.router_config.max_instances, 4)
  desired_instances = try(var.security_config.gwlb.router_config.desired_instances, 2)

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-gwlb"
    Environment = var.environment
    Purpose     = "simple-routing-no-inspection"
    Type        = "gwlb-linux-routers"
  })

  depends_on = [module.inspection_vpc]
}

# Debug output to check GWLB ARN
resource "null_resource" "debug_gwlb" {
  count = var.security_config.gwlb.enabled ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'GWLB ARN: ${module.gwlb[0].gwlb_arn}'"
  }

  depends_on = [module.gwlb]
}

# Store GWLB service name in SSM for cross-account sharing
resource "aws_ssm_parameter" "gwlb_service_name" {
  provider = aws.security

  count       = var.security_config.gwlb.enabled ? 1 : 0
  name        = "/aft/network/inspection/gwlb/service-name"
  description = "GWLB endpoint service name for endpoint creation"
  type        = "String"
  value       = module.gwlb[0].gwlb_endpoint_service_name

  depends_on = [module.gwlb]
  tags       = var.tags
}

# VPC Endpoint Service is already created by the GWLB module
# Store the service name for cross-account access
resource "aws_ssm_parameter" "gwlb_endpoint_service" {
  provider = aws.security

  count       = var.security_config.gwlb.enabled ? 1 : 0
  name        = "/aft/network/inspection/gwlb/endpoint-service-name"
  description = "GWLB VPC Endpoint Service name for cross-account access"
  type        = "String"
  value       = module.gwlb[0].gwlb_endpoint_service_name

  depends_on = [module.gwlb]
  tags       = var.tags
}