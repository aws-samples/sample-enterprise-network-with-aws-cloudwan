output "alb_name" {
  description = "The ARN suffix of the ALB"
  value       = one(aws_lb.default[*].name)
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = one(aws_lb.default[*].arn)
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB"
  value       = one(aws_lb.default[*].arn_suffix)
}

output "alb_dns_name" {
  description = "DNS name of ALB"
  value       = one(aws_lb.default[*].dns_name)
}

output "alb_zone_id" {
  description = "The ID of the zone which ALB is provisioned"
  value       = one(aws_lb.default[*].zone_id)
}

output "security_group_id" {
  description = "The security group ID of the ALB"
  value       = one(aws_security_group.default[*].id)
}

output "default_target_group_arn" {
  description = "The default target group ARN"
  value       = one(aws_lb_target_group.default[*].arn)
}

output "default_target_group_arn_suffix" {
  description = "The default target group ARN suffix"
  value       = one(aws_lb_target_group.default[*].arn_suffix)
}

output "http_listener_arn" {
  description = "The ARN of the HTTP forwarding listener"
  value       = one(aws_lb_listener.http_forward[*].arn)
}

output "http_redirect_listener_arn" {
  description = "The ARN of the HTTP to HTTPS redirect listener"
  value       = one(aws_lb_listener.http_redirect[*].arn)
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = one(aws_lb_listener.https[*].arn)
}

output "listener_arns" {
  description = "A list of all the listener ARNs"
  value = compact(
    concat(aws_lb_listener.http_forward[*].arn, aws_lb_listener.http_redirect[*].arn, aws_lb_listener.https[*].arn)
  )
}

output "access_logs_bucket_id" {
  description = "The S3 bucket ID for access logs"
  value       = one(aws_s3_bucket.access_logs[*].id)
}

output "vpc_id" {
  description = "The VPC ID used by the ALB"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "The subnet IDs used by the ALB"
  value       = local.subnet_ids
}

output "target_groups" {
  description = "Map of additional target groups created"
  value = {
    for k, v in aws_lb_target_group.additional : k => {
      arn        = v.arn
      arn_suffix = v.arn_suffix
      name       = v.name
      port       = v.port
      protocol   = v.protocol
    }
  }
}

output "target_group_arns" {
  description = "Map of target group ARNs (key = target group name, value = ARN)"
  value = merge(
    var.default_target_group_enabled ? { "default" = one(aws_lb_target_group.default[*].arn) } : {},
    { for k, v in aws_lb_target_group.additional : k => v.arn }
  )
}

output "listener_rules" {
  description = "Map of listener rules created"
  value = {
    for k, v in aws_lb_listener_rule.rules : k => {
      arn      = v.arn
      priority = v.priority
    }
  }
}


