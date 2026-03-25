# Gateway Load Balancer Module
# Simple pass-through routing without inspection

locals {
  name_prefix = var.name_prefix
  common_tags = merge(var.tags, {
    Module = "gwlb"
  })
}

# Security Group for Router Instances
resource "aws_security_group" "router_instances" {
  name        = "${local.name_prefix}-router-instances"
  description = "Security group for GWLB router instances"
  vpc_id      = var.vpc_id

  # Allow all inbound traffic from VPC CIDR (for GWLB health checks and traffic)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all from VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-router-sg"
  })
}

# IAM Role for Router Instances
resource "aws_iam_role" "router_instance" {
  name = "${local.name_prefix}-router-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# Attach SSM policy for management
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.router_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "router_instance" {
  name = "${local.name_prefix}-router-instance-profile"
  role = aws_iam_role.router_instance.name

  tags = local.common_tags
}

# Launch Template for Router Instances
resource "aws_launch_template" "router" {
  name_prefix   = "${local.name_prefix}-router-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.router_instance.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.router_instances.id]
    delete_on_termination       = true
  }

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/userdata-router.sh", {
    region = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-router"
      Role = "gwlb-router"
    })
  }

  tags = local.common_tags
}

# S3 bucket for GWLB access logs (CKV_AWS_2)
resource "aws_s3_bucket" "gwlb_logs" {
  bucket = "${local.name_prefix}-gwlb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gwlb-logs"
  })
}

resource "aws_s3_bucket_versioning" "gwlb_logs" {
  bucket = aws_s3_bucket.gwlb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "gwlb_logs" {
  bucket = aws_s3_bucket.gwlb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "gwlb_logs" {
  bucket = aws_s3_bucket.gwlb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "gwlb_logs" {
  bucket = aws_s3_bucket.gwlb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowGWLBLogging"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.gwlb_logs.arn}/*"
      },
      {
        Sid       = "AllowGetBucketAcl"
        Effect    = "Allow"
        Principal = { Service = "elasticloadbalancing.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.gwlb_logs.arn
      }
    ]
  })
}

# Data source for current account ID
data "aws_caller_identity" "current" {}

# Gateway Load Balancer
resource "aws_lb" "gwlb" {
  name               = "${local.name_prefix}-gwlb"
  load_balancer_type = "gateway"
  subnets            = var.gwlb_subnet_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true

  access_logs {
    bucket  = aws_s3_bucket.gwlb_logs.id
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gwlb"
  })

  depends_on = [aws_s3_bucket_policy.gwlb_logs]
}

# Target Group for GWLB
resource "aws_lb_target_group" "gwlb" {
  name     = "${local.name_prefix}-gwlb-tg"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = 22
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gwlb-tg"
  })
}

# GWLB Listener
resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb.arn
  }

  tags = local.common_tags
}

# Auto Scaling Group for Router Instances
resource "aws_autoscaling_group" "router" {
  name                = "${local.name_prefix}-router-asg"
  vpc_zone_identifier = var.router_subnet_ids
  target_group_arns   = [aws_lb_target_group.gwlb.arn]

  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.desired_instances

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.router.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-router"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# VPC Endpoint Service for GWLB
resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = true
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gwlb-endpoint-service"
  })
}

# GWLB Endpoints (one per AZ)
resource "aws_vpc_endpoint" "gwlb" {
  for_each = var.gwlb_endpoint_subnets

  vpc_id            = var.vpc_id
  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [each.value]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-gwlb-endpoint-${each.key}"
    AZ   = each.key
  })
}
