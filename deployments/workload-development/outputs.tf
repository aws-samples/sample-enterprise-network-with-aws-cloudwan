output "vpc_id" {
  description = "Development VPC ID"
  value       = module.development_vpc.vpc_id
}

output "vpc_cidr" {
  description = "Development VPC CIDR block"
  value       = module.development_vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = values(module.development_vpc.subnets["private"])
}

output "transit_subnet_ids" {
  description = "Transit subnet IDs for CloudWAN attachment"
  value       = values(module.development_vpc.subnets["transit"])
}

output "cloudwan_attachment_id" {
  description = "CloudWAN VPC attachment ID"
  value       = module.development_vpc.cloudwan_attachment_id
}

output "cloudwan_attachment_arn" {
  description = "CloudWAN VPC attachment ARN"
  value       = module.development_vpc.cloudwan_attachment_arn
}

output "dev_instance_ids" {
  description = "Development application instance IDs"
  value       = module.dev_application.instance_ids
}

output "dev_instance_private_ips" {
  description = "Development application instance private IPs"
  value       = module.dev_application.instance_private_ips
}

output "security_group_id" {
  description = "Security group ID for development instances"
  value       = module.dev_application.security_group_id
}
