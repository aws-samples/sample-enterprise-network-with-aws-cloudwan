data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Direct Connect Gateway
resource "aws_dx_gateway" "main" {
  name            = "${var.environment}-dx-gateway"
  amazon_side_asn = var.dx_gateway_asn
}

# Private Virtual Interface (VIF)
resource "aws_dx_private_virtual_interface" "main" {
  count          = var.dx_connection_id != null ? 1 : 0
  connection_id  = var.dx_connection_id
  name           = "${var.environment}-private-vif"
  vlan           = var.vlan_id
  address_family = "ipv4"
  bgp_asn        = var.customer_bgp_asn
  dx_gateway_id  = aws_dx_gateway.main.id

  # Optional BGP authentication
  bgp_auth_key = var.bgp_auth_key

  tags = merge(var.tags, {
    Name        = "${var.environment}-private-vif"
    Environment = var.environment
  })
}

# Direct Connect Gateway Association with CloudWAN
resource "aws_dx_gateway_association" "cloudwan" {
  dx_gateway_id         = aws_dx_gateway.main.id
  associated_gateway_id = var.core_network_id

  allowed_prefixes = var.allowed_prefixes
}

# KMS key for SSM parameter encryption (CKV_AWS_337)
resource "aws_kms_key" "ssm_parameters" {
  description             = "KMS key for SSM parameter encryption in Direct Connect"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.environment}-dx-ssm-parameters"
  })
}

resource "aws_kms_alias" "ssm_parameters" {
  name          = "alias/${var.environment}-dx-ssm-parameters"
  target_key_id = aws_kms_key.ssm_parameters.key_id
}

# Store DX configuration in SSM for cross-account access
resource "aws_ssm_parameter" "dx_config" {
  name        = "/aft/network/dx/config"
  description = "Direct Connect configuration"
  type        = "SecureString"
  key_id      = aws_kms_key.ssm_parameters.id
  value = jsonencode({
    dx_gateway_id     = aws_dx_gateway.main.id
    dx_gateway_name   = aws_dx_gateway.main.name
    vif_id            = var.dx_connection_id != null ? aws_dx_private_virtual_interface.main[0].id : null
    dx_association_id = aws_dx_gateway_association.cloudwan.id
    segment           = "hybrid"
    environment       = var.environment
  })

  tags = var.tags
}