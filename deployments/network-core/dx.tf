# Direct Connect integration for on-premises connectivity
module "direct_connect" {
  count  = var.dx_config.enabled ? 1 : 0
  source = "../../modules/direct-connect"

  environment     = var.environment
  core_network_id = var.is_primary_region ? module.cloudwan[0].core_network_id : var.core_network_id

  # DX Configuration
  dx_connection_id = var.dx_config.connection_id
  dx_gateway_asn   = var.dx_config.gateway_asn
  customer_bgp_asn = var.dx_config.customer_bgp_asn
  vlan_id          = var.dx_config.vlan_id
  bgp_auth_key     = var.dx_config.bgp_auth_key
  allowed_prefixes = var.dx_config.allowed_prefixes

  tags = merge(var.tags, {
    Purpose = "on-premises-connectivity"
    Segment = "hybrid"
  })
}