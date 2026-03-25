# CheckPoint Firewall Configuration for Network Inspection

# Get current AWS account ID for S3 bucket naming
data "aws_caller_identity" "current" {
  provider = aws.security
}

# CheckPoint CloudGuard Network Security AMI lookup
data "aws_ami" "checkpoint" {
  count       = var.security_config.checkpoint.enabled ? 1 : 0
  provider    = aws.security
  most_recent = true
  owners      = ["679593333241"] # CheckPoint official AWS account

  filter {
    name   = "name"
    values = ["*Check*Point*", "*CloudGuard*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Fallback AMI ID if data source fails
locals {
  checkpoint_ami_id = var.security_config.checkpoint.enabled && length(data.aws_ami.checkpoint) > 0 ? data.aws_ami.checkpoint[0].id : "ami-0abcdef1234567890" # Replace with actual AMI ID
}

# Security Group for CheckPoint instances
resource "aws_security_group" "checkpoint" {
  count       = var.security_config.checkpoint.enabled ? 1 : 0
  provider    = aws.security
  name        = "${local.name_prefix}-checkpoint-sg"
  description = "Security group for CheckPoint instances"
  vpc_id      = module.inspection_vpc.vpc_id

  ingress {
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "GENEVE protocol for GWLB traffic"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from all AWS internal networks
    description = "All TCP traffic from private networks"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from all AWS internal networks
    description = "All UDP traffic from private networks"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.128.8.0/21"] # Management subnet access only
    description = "SSH access from management subnets"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.128.8.0/21"] # Management subnet access only
    description = "HTTPS management access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-sg"
    Environment = var.environment
    Purpose     = "checkpoint-firewall"
  })
}

# S3 bucket for NLB access logs (CKV_AWS_338)
resource "aws_s3_bucket" "checkpoint_nlb_logs" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  bucket   = "${local.name_prefix}-checkpoint-nlb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-nlb-logs"
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "checkpoint_nlb_logs" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  bucket   = aws_s3_bucket.checkpoint_nlb_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "checkpoint_nlb_logs" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  bucket   = aws_s3_bucket.checkpoint_nlb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "checkpoint_nlb_logs" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  bucket   = aws_s3_bucket.checkpoint_nlb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "checkpoint_nlb_logs" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  bucket   = aws_s3_bucket.checkpoint_nlb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowNLBLogging"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.checkpoint_nlb_logs[0].arn}/*"
      },
      {
        Sid       = "AllowGetBucketAcl"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.checkpoint_nlb_logs[0].arn
      }
    ]
  })
}

# Network Load Balancer for CheckPoint (when not using GWLB)
resource "aws_lb" "checkpoint" {
  count              = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider           = aws.security
  name               = "${local.name_prefix}-checkpoint-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = values(module.inspection_vpc.subnets["inspection"])

  enable_cross_zone_load_balancing = true

  access_logs {
    bucket  = aws_s3_bucket.checkpoint_nlb_logs[0].id
    enabled = true
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-nlb"
    Environment = var.environment
    Purpose     = "checkpoint-load-balancer"
  })

  depends_on = [aws_s3_bucket_policy.checkpoint_nlb_logs]
}

# Target Group for CheckPoint NLB
resource "aws_lb_target_group" "checkpoint" {
  count    = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider = aws.security
  name     = "${local.name_prefix}-checkpoint-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = module.inspection_vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "443"
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-tg"
    Environment = var.environment
  })
}

# NLB Listener for CheckPoint
resource "aws_lb_listener" "checkpoint" {
  count             = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider          = aws.security
  load_balancer_arn = aws_lb.checkpoint[0].arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.checkpoint[0].arn
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-listener"
    Environment = var.environment
  })
}

# Launch Template for CheckPoint instances
resource "aws_launch_template" "checkpoint" {
  count         = var.security_config.checkpoint.enabled ? 1 : 0
  provider      = aws.security
  name          = "${local.name_prefix}-checkpoint-lt"
  image_id      = local.checkpoint_ami_id
  instance_type = var.security_config.checkpoint.instance_type

  vpc_security_group_ids = [aws_security_group.checkpoint[0].id]

  user_data = base64encode(templatefile("${path.module}/templates/checkpoint-userdata.sh", {
    region                   = var.region
    checkpoint_password      = var.checkpoint_password
    sic_key                  = var.checkpoint_sic_key
    checkpoint_password_hash = var.checkpoint_password_hash
  }))

  # Enforce IMDSv2 (CKV_AWS_150)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name        = "${local.name_prefix}-checkpoint-instance"
      Environment = var.environment
      Purpose     = "checkpoint-firewall"
    })
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-lt"
    Environment = var.environment
  })
}

# Auto Scaling Group for CheckPoint instances
resource "aws_autoscaling_group" "checkpoint" {
  count                     = var.security_config.checkpoint.enabled ? 1 : 0
  provider                  = aws.security
  name                      = "${local.name_prefix}-checkpoint-asg"
  desired_capacity          = var.security_config.checkpoint.desired_capacity
  max_size                  = var.security_config.checkpoint.max_size
  min_size                  = var.security_config.checkpoint.min_size
  vpc_zone_identifier       = values(module.inspection_vpc.subnets["inspection"])
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Target group depends on whether GWLB is enabled
  target_group_arns = var.security_config.gwlb.enabled ? (
    length(module.gwlb) > 0 ? [module.gwlb[0].target_group_arn] : []
    ) : (
    length(aws_lb_target_group.checkpoint) > 0 ? [aws_lb_target_group.checkpoint[0].arn] : []
  )

  launch_template {
    id      = aws_launch_template.checkpoint[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-checkpoint-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Purpose"
    value               = "checkpoint-firewall"
    propagate_at_launch = true
  }

  depends_on = [
    aws_launch_template.checkpoint,
    module.gwlb,
    aws_lb_target_group.checkpoint
  ]
}

# CloudWatch Log Groups for CheckPoint monitoring
resource "aws_cloudwatch_log_group" "checkpoint_system" {
  count             = var.security_config.checkpoint.enabled ? 1 : 0
  provider          = aws.security
  name              = "/aws/ec2/checkpoint/system"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-system-logs"
    Environment = var.environment
    Purpose     = "checkpoint-system-monitoring"
  })
}

resource "aws_cloudwatch_log_group" "checkpoint_firewall" {
  count             = var.security_config.checkpoint.enabled ? 1 : 0
  provider          = aws.security
  name              = "/aws/ec2/checkpoint/firewall"
  retention_in_days = 90 # Longer retention for security logs

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-checkpoint-firewall-logs"
    Environment = var.environment
    Purpose     = "checkpoint-security-monitoring"
  })
}

# CloudWatch Log Groups for CheckPoint NLB (when not using GWLB)
resource "aws_cloudwatch_log_group" "checkpoint_nlb" {
  count             = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider          = aws.security
  name              = "/aws/networkloadbalancer/${local.name_prefix}-checkpoint"
  retention_in_days = 30

  tags = var.tags
}

# CloudWatch Metric Alarms for CheckPoint
resource "aws_cloudwatch_metric_alarm" "checkpoint_unhealthy_hosts" {
  count               = var.security_config.checkpoint.enabled && !var.security_config.gwlb.enabled ? 1 : 0
  provider            = aws.security
  alarm_name          = "${local.name_prefix}-checkpoint-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "CheckPoint NLB unhealthy hosts"

  dimensions = {
    TargetGroup  = aws_lb_target_group.checkpoint[0].arn_suffix
    LoadBalancer = aws_lb.checkpoint[0].arn_suffix
  }

  tags = var.tags
}

# GWLB Target Health Alarm
resource "aws_cloudwatch_metric_alarm" "gwlb_unhealthy_targets" {
  count               = var.security_config.checkpoint.enabled && var.security_config.gwlb.enabled ? 1 : 0
  provider            = aws.security
  alarm_name          = "${local.name_prefix}-gwlb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/GatewayELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "GWLB unhealthy CheckPoint targets"

  dimensions = {
    TargetGroup  = module.gwlb[0].target_group_arn
    LoadBalancer = module.gwlb[0].gwlb_arn
  }

  tags = var.tags
}

# CheckPoint Instance CPU Alarm
resource "aws_cloudwatch_metric_alarm" "checkpoint_high_cpu" {
  count               = var.security_config.checkpoint.enabled ? 1 : 0
  provider            = aws.security
  alarm_name          = "${local.name_prefix}-checkpoint-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CheckPoint instance high CPU utilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.checkpoint[0].name
  }

  tags = var.tags
}

# CheckPoint Instance Memory Alarm
resource "aws_cloudwatch_metric_alarm" "checkpoint_high_memory" {
  count               = var.security_config.checkpoint.enabled ? 1 : 0
  provider            = aws.security
  alarm_name          = "${local.name_prefix}-checkpoint-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "mem_used_percent"
  namespace           = "CheckPoint/Security"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "CheckPoint instance high memory utilization"

  tags = var.tags
}