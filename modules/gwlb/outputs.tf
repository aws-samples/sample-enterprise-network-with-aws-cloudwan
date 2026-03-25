output "gwlb_id" {
  description = "Gateway Load Balancer ID"
  value       = aws_lb.gwlb.id
}

output "gwlb_arn" {
  description = "Gateway Load Balancer ARN"
  value       = aws_lb.gwlb.arn
}

output "gwlb_endpoint_service_name" {
  description = "GWLB VPC Endpoint Service name"
  value       = aws_vpc_endpoint_service.gwlb.service_name
}

output "gwlb_endpoint_ids" {
  description = "Map of AZ to GWLB endpoint ID"
  value       = { for k, v in aws_vpc_endpoint.gwlb : k => v.id }
}

output "gwlb_endpoint_enis" {
  description = "Map of AZ to GWLB endpoint ENI IDs"
  value       = { for k, v in aws_vpc_endpoint.gwlb : k => v.network_interface_ids }
}

output "target_group_arn" {
  description = "GWLB target group ARN"
  value       = aws_lb_target_group.gwlb.arn
}

output "router_security_group_id" {
  description = "Security group ID for router instances"
  value       = aws_security_group.router_instances.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name for router instances"
  value       = aws_autoscaling_group.router.name
}
