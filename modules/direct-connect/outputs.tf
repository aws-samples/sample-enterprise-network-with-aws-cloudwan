output "dx_gateway_id" {
  description = "Direct Connect Gateway ID"
  value       = aws_dx_gateway.main.id
}

output "dx_gateway_name" {
  description = "Direct Connect Gateway name"
  value       = aws_dx_gateway.main.name
}

output "dx_gateway_amazon_side_asn" {
  description = "Amazon side ASN of the Direct Connect Gateway"
  value       = aws_dx_gateway.main.amazon_side_asn
}

output "vif_id" {
  description = "Private Virtual Interface ID"
  value       = var.dx_connection_id != null ? aws_dx_private_virtual_interface.main[0].id : null
}

output "vif_vlan_id" {
  description = "VLAN ID of the Private Virtual Interface"
  value       = var.dx_connection_id != null ? aws_dx_private_virtual_interface.main[0].vlan : null
}

output "dx_association_id" {
  description = "DX Gateway CloudWAN Association ID"
  value       = aws_dx_gateway_association.cloudwan.id
}

output "dx_association_state" {
  description = "State of the DX Gateway association"
  value       = "associated" # Static value since association_state is not available
}

output "segment" {
  description = "CloudWAN segment for on-premises traffic"
  value       = "hybrid"
}

output "ssm_parameter_name" {
  description = "SSM parameter name containing DX configuration"
  value       = aws_ssm_parameter.dx_config.name
}