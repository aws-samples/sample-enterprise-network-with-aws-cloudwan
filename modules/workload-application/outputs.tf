output "instance_ids" {
  description = "IDs of the application instances"
  value       = aws_instance.application[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of the application instances"
  value       = aws_instance.application[*].private_ip
}

output "security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.application.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role (if created)"
  value       = var.iam_config.instance_profile_name == null || var.iam_config.instance_profile_name == "" ? (length(aws_iam_role.default_ec2_role) > 0 ? aws_iam_role.default_ec2_role[0].arn : null) : null
}

output "instance_profile_name" {
  description = "Name of the instance profile used"
  value       = local.instance_profile_name
}