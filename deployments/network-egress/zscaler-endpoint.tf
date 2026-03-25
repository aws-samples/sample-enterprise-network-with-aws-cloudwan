# Store egress GWLB endpoint details in SSM (only if modules exist)
resource "aws_ssm_parameter" "checkpoint_endpoint" {
  provider = aws.network-services

  count       = 0 # Disabled - no checkpoint_gwlb_endpoint module
  name        = "/aft/network/egress/checkpoint-gwlb-endpoint"
  description = "CheckPoint GWLB endpoint configuration in egress account"
  type        = "SecureString"
  value = jsonencode({
    endpoint_details = {}
    subnet_ids       = values(module.egress_vpc.subnets["firewall"])
    environment      = var.environment
  })

  tags = var.tags
}

resource "aws_ssm_parameter" "zscaler_endpoint" {
  provider = aws.network-services

  count       = 0 # Disabled - no zscaler_gwlb_endpoint module
  name        = "/aft/network/egress/zscaler-gwlb-endpoint"
  description = "Zscaler GWLB endpoint configuration in egress account"
  type        = "SecureString"
  value = jsonencode({
    endpoint_details = {}
    subnet_ids       = []
    environment      = var.environment
  })

  tags = var.tags
}