# Network Firewall Module Outputs

output "firewall_id" {
  description = "Network Firewall ID"
  value       = aws_networkfirewall_firewall.main.id
}

output "firewall_arn" {
  description = "Network Firewall ARN"
  value       = aws_networkfirewall_firewall.main.arn
}

output "firewall_name" {
  description = "Network Firewall name"
  value       = aws_networkfirewall_firewall.main.name
}

output "firewall_policy_arn" {
  description = "Network Firewall Policy ARN"
  value       = aws_networkfirewall_firewall_policy.main.arn
}

output "firewall_endpoints" {
  description = "Map of AZ to firewall endpoint ID"
  value       = local.firewall_endpoints
}

output "firewall_endpoint_ids" {
  description = "List of firewall endpoint IDs"
  value       = local.firewall_endpoint_ids_list
}

output "log_group_name" {
  description = "CloudWatch log group name for firewall logs"
  value       = aws_cloudwatch_log_group.network_firewall.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for firewall logs"
  value       = aws_cloudwatch_log_group.network_firewall.arn
}
