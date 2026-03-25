output "global_network_id" {
  description = "ID of the global network"
  value       = aws_networkmanager_global_network.main.id
}

output "core_network_id" {
  description = "ID of the core network"
  value       = aws_networkmanager_core_network.main.id
}

output "core_network_arn" {
  description = "ARN of the core network"
  value       = aws_networkmanager_core_network.main.arn
}

output "segments" {
  description = "List of network segments"
  value       = local.core_network_policy.segments
}

output "policy_document" {
  description = "Core network policy document"
  value       = jsonencode(local.core_network_policy)
}

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share for CloudWAN"
  value       = var.is_primary_region && var.enable_ram_sharing ? aws_ram_resource_share.cloudwan[0].arn : null
}

output "ram_resource_share_id" {
  description = "ID of the RAM resource share for CloudWAN"
  value       = var.is_primary_region && var.enable_ram_sharing ? aws_ram_resource_share.cloudwan[0].id : null
}

# VPC Attachment Outputs
output "vpc_attachment_ids" {
  description = "Map of VPC attachment IDs"
  value       = { for k, v in aws_networkmanager_vpc_attachment.network_services : k => v.id }
}

output "vpc_attachment_arns" {
  description = "Map of VPC attachment ARNs"
  value       = { for k, v in aws_networkmanager_vpc_attachment.network_services : k => v.arn }
}

