output "vpc_id" {
  description = "ID of the inspection VPC"
  value       = module.inspection_vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the inspection VPC"
  value       = local.vpc_cidr
}

output "subnet_ids" {
  description = "Map of subnet IDs by type"
  value       = module.inspection_vpc.subnets
}

output "route_table_ids" {
  description = "Map of route table IDs"
  value       = module.inspection_vpc.route_table_ids
}

output "subnet_configuration" {
  description = "Subnet configuration used by the module"
  value       = local.subnet_configuration
}

output "global_cidr_ranges" {
  description = "Global CIDR ranges from IPAM pool"
  value       = local.aws_cidr_ranges
}

# output "core_network_id" {
#   description = "CloudWAN Core Network ID"
#   value       = local.core_network_id
#   sensitive   = true
# }

# output "checkpoint_services" {
#   description = "CheckPoint security services"
#   value = var.security_config.checkpoint.enabled ? {
#     nlb_dns_name     = var.security_config.gwlb.enabled ? null : (length(aws_lb.checkpoint) > 0 ? aws_lb.checkpoint[0].dns_name : null)
#     nlb_arn          = var.security_config.gwlb.enabled ? null : (length(aws_lb.checkpoint) > 0 ? aws_lb.checkpoint[0].arn : null)
#     target_group_arn = var.security_config.gwlb.enabled ? (length(module.gwlb) > 0 ? module.gwlb[0].target_group_arn : null) : (length(aws_lb_target_group.checkpoint) > 0 ? aws_lb_target_group.checkpoint[0].arn : null)
#     asg_name         = length(aws_autoscaling_group.checkpoint) > 0 ? aws_autoscaling_group.checkpoint[0].name : null
#   } : null
#}

output "cwan_attachment_id" {
  description = "CloudWAN VPC attachment ID"
  value       = module.inspection_vpc.cloudwan_attachment_id
}

output "gwlb_services" {
  description = "Gateway Load Balancer services"
  value = var.security_config.gwlb.enabled ? {
    gwlb_arn              = length(module.gwlb) > 0 ? module.gwlb[0].gwlb_arn : null
    endpoint_service_name = length(module.gwlb) > 0 ? module.gwlb[0].gwlb_endpoint_service_name : null
    target_group_arn      = length(module.gwlb) > 0 ? module.gwlb[0].target_group_arn : null
    gwlb_endpoint_ids     = length(module.gwlb) > 0 ? module.gwlb[0].gwlb_endpoint_ids : null
    router_asg_name       = length(module.gwlb) > 0 ? module.gwlb[0].autoscaling_group_name : null
  } : null
}