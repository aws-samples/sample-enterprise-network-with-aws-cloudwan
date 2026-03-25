output "vpc_id" {
  description = "ID of the application VPC"
  value       = module.application_vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the application VPC"
  value       = module.application_vpc.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = values(module.application_vpc.subnets["private"])
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = values(module.application_vpc.subnets["database"])
}

output "application_instances" {
  description = "Application instance information"
  value = {
    instance_ids      = module.web_application.instance_ids
    security_group_id = module.web_application.security_group_id
    iam_role_arn      = module.web_application.iam_role_arn
  }
}

output "internal_alb" {
  description = "Internal ALB information for CloudFront VPC Origins"
  value = {
    alb_arn          = module.internal_alb.alb_arn
    alb_dns_name     = module.internal_alb.alb_dns_name
    alb_zone_id      = module.internal_alb.alb_zone_id
    target_group_arn = module.internal_alb.default_target_group_arn
  }
}

# VPC Origin output disabled - vpc-origin.tf is disabled for production
# output "vpc_origin" {
#   description = "VPC Origin information for CloudFront"
#   value = {
#     vpc_origin_id     = aws_cloudfront_vpc_origin.internal_alb.id
#     vpc_origin_arn    = aws_cloudfront_vpc_origin.internal_alb.arn
#     ram_share_id      = aws_ram_resource_share.vpc_origin.id
#     ram_share_arn     = aws_ram_resource_share.vpc_origin.arn
#   }
# }

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = null # Database not created in this simplified version
  sensitive   = true
}

output "cloudwan_attachment_id" {
  description = "CloudWAN VPC attachment ID"
  value       = module.application_vpc.cloudwan_attachment_id
}

output "vpc_endpoints" {
  description = "VPC endpoints information"
  value       = {}
}