# Workload Application Module for Application Deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name_prefix = "${var.environment}-${var.application_name}"
}

# Security Groups for Applications
resource "aws_security_group" "application" {
  name_prefix = "${local.name_prefix}-app-"
  vpc_id      = var.vpc_id
  description = "Security group for ${var.application_name} application"

  dynamic "ingress" {
    for_each = var.security_config.ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      description     = ingress.value.description
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", null)
      security_groups = lookup(ingress.value, "security_groups", null)
    }
  }

  dynamic "egress" {
    for_each = var.security_config.egress_rules
    content {
      from_port       = egress.value.from_port
      to_port         = egress.value.to_port
      protocol        = egress.value.protocol
      description     = egress.value.description
      cidr_blocks     = lookup(egress.value, "cidr_blocks", null)
      security_groups = lookup(egress.value, "security_groups", null)
    }
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-app-sg"
  })
}

# Default IAM role for EC2 instances (if not provided)
resource "aws_iam_role" "default_ec2_role" {
  count = var.iam_config.instance_profile_name == null || var.iam_config.instance_profile_name == "" ? 1 : 0
  name  = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

# Attach basic policies to default role
resource "aws_iam_role_policy_attachment" "default_ec2_ssm" {
  count      = var.iam_config.instance_profile_name == null || var.iam_config.instance_profile_name == "" ? 1 : 0
  role       = aws_iam_role.default_ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "default_ec2_cloudwatch" {
  count      = var.iam_config.instance_profile_name == null || var.iam_config.instance_profile_name == "" ? 1 : 0
  role       = aws_iam_role.default_ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Default instance profile
resource "aws_iam_instance_profile" "default_ec2_profile" {
  count = var.iam_config.instance_profile_name == null || var.iam_config.instance_profile_name == "" ? 1 : 0
  name  = "${local.name_prefix}-ec2-profile"
  role  = aws_iam_role.default_ec2_role[0].name

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-ec2-profile"
  })
}

# Data source for existing instance profile (if specified)
data "aws_iam_instance_profile" "existing" {
  count = var.iam_config.instance_profile_name != null && var.iam_config.instance_profile_name != "" ? 1 : 0
  name  = var.iam_config.instance_profile_name
}

locals {
  instance_profile_name = var.iam_config.instance_profile_name != null && var.iam_config.instance_profile_name != "" ? var.iam_config.instance_profile_name : (
    length(aws_iam_instance_profile.default_ec2_profile) > 0 ? aws_iam_instance_profile.default_ec2_profile[0].name : "${local.name_prefix}-ec2-profile"
  )
}

# Application Instances
resource "aws_instance" "application" {
  count                  = length(var.subnet_ids) > 0 ? var.instance_config.count : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_config.instance_type
  key_name               = var.instance_config.key_name
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.application.id]
  iam_instance_profile   = local.instance_profile_name
  ebs_optimized          = true
  monitoring             = true

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypt root volume
  root_block_device {
    encrypted = true
  }

  user_data = base64encode(templatefile(var.user_data_config.template_file, merge(
    var.user_data_config.template_vars,
    {
      instance_index = count.index
    }
  )))

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-${count.index + 1}"
    Environment = var.environment
    Type        = "application-server"
  })
}

# Security Groups for VPC Endpoints (if creating individual VPCs)
resource "aws_security_group" "vpc_endpoints" {
  count       = var.vpc_endpoints_config.enabled ? 1 : 0
  name_prefix = "${local.name_prefix}-vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTP from VPC (for S3)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  })
}

# Additional security group rule to allow application instances to access VPC endpoints
resource "aws_security_group_rule" "vpc_endpoints_from_app" {
  count                    = var.vpc_endpoints_config.enabled ? 1 : 0
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  description              = "HTTPS from application instances"
  source_security_group_id = aws_security_group.application.id
  security_group_id        = aws_security_group.vpc_endpoints[0].id
}

# Convert subnet list to map for vpc_endpoints module
locals {
  # Convert list of subnet IDs to map of AZ -> subnet ID
  # This is a simplified approach - in a real scenario you'd want to get actual AZ info
  subnet_map = var.vpc_endpoints_config.enabled ? {
    for idx, subnet_id in var.subnet_ids :
    "subnet-${idx}" => subnet_id
  } : {}
}

# VPC Endpoints for AWS Services (if enabled)
module "vpc_endpoints" {
  count  = var.vpc_endpoints_config.enabled ? 1 : 0
  source = "../endpoints"

  providers = {
    aws = aws
  }

  region            = data.aws_region.current.name
  vpc_id            = var.vpc_id
  subnet_ids        = local.subnet_map
  route_table_ids   = var.route_table_ids
  endpoint_services = var.vpc_endpoints_config.services
  security_group_id = aws_security_group.vpc_endpoints[0].id

  tags = merge(var.tags, {
    Environment = var.environment
    Application = var.application_name
  })
}