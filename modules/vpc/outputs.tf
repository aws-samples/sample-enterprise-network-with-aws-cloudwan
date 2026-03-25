output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "ipam_allocation_id" {
  description = "IPAM pool CIDR allocation ID (if IPAM allocation is enabled)"
  value       = var.ipam_allocation.enabled ? aws_vpc_ipam_pool_cidr_allocation.vpc[0].id : null
}

output "ipam_allocation_cidr" {
  description = "IPAM allocated CIDR block (if IPAM allocation is enabled)"
  value       = var.ipam_allocation.enabled ? aws_vpc_ipam_pool_cidr_allocation.vpc[0].cidr : null
}

output "subnets" {
  description = "Map of subnet IDs by type and AZ"
  value = {
    for type in local.subnet_types : type => {
      for subnet_key, subnet in aws_subnet.subnets :
      subnet.availability_zone => subnet.id
      if split("-", subnet_key)[0] == type
    }
  }
}

output "route_tables" {
  description = "Map of route table IDs by type"
  value = {
    for type, rt in local.route_tables : type => rt.id
  }
}

output "route_table_ids" {
  description = "Map of route table IDs"
  value = {
    for type, rt in local.route_tables : type => rt.id
  }
}

output "vpc_tags" {
  description = "Tags applied to the VPC"
  value       = local.vpc_tags
}

# CloudWAN Outputs
output "cloudwan_attachment_id" {
  description = "CloudWAN VPC attachment ID"
  value       = var.cloudwan_config.enabled ? aws_networkmanager_vpc_attachment.main[0].id : null
}

output "cloudwan_attachment_arn" {
  description = "CloudWAN VPC attachment ARN"
  value       = var.cloudwan_config.enabled ? aws_networkmanager_vpc_attachment.main[0].arn : null
}

# RAM Sharing Outputs
output "ram_resource_share_arn" {
  description = "RAM resource share ARN"
  value       = var.ram_sharing_config.enabled ? aws_ram_resource_share.vpc[0].arn : null
}

output "ram_resource_share_id" {
  description = "RAM resource share ID"
  value       = var.ram_sharing_config.enabled ? aws_ram_resource_share.vpc[0].id : null
}

# Internet Gateway Output
output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = var.vpc_configuration.features.create_igw ? aws_internet_gateway.main[0].id : null
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.vpc_configuration.features.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "List of public IPs assigned to NAT Gateways"
  value       = var.vpc_configuration.features.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# VPC Flow Logs Outputs
output "flow_log_id" {
  description = "VPC Flow Log ID"
  value       = var.vpc_configuration.features.enable_flow_logs ? aws_flow_log.main[0].id : null
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  value       = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

output "flow_log_group_arn" {
  description = "CloudWatch Log Group ARN for VPC Flow Logs"
  value       = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}

output "flow_log_role_arn" {
  description = "IAM Role ARN for VPC Flow Logs"
  value       = var.vpc_configuration.features.enable_flow_logs && var.create_flow_log_resources ? aws_iam_role.flow_logs[0].arn : null
}
