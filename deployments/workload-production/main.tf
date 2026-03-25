terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# Provider configuration for Application Account
provider "aws" {
  alias  = "application"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.application_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project     = "enterprise-network"
      Environment = var.environment
      ManagedBy   = "terraform"
      Account     = "application"
      Deployment  = "application-account"
    }
  }
}

# Provider for Network Services Account (to get shared resources)
provider "aws" {
  alias  = "network-services"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Get caller identity for both accounts
data "aws_caller_identity" "application" {
  provider = aws.application
}

data "aws_caller_identity" "network_services" {
  provider = aws.network-services
}

# Get CloudWAN Core Network ID from SSM parameter in network services account
data "aws_ssm_parameter" "core_network_id" {
  provider = aws.network-services
  name     = "/aft/network/core/network-id"
}

# Get IPAM Pool for application VPCs from Network Services Account
data "aws_vpc_ipam_pool" "application" {
  provider = aws.network-services

  filter {
    name   = "tag:Name"
    values = ["workload-${var.region}-ipam-pool"]
  }
}

# Get IPAM Pool CIDR ranges for network services
data "aws_vpc_ipam_pool" "network" {
  provider = aws.network-services

  filter {
    name   = "tag:Name"
    values = ["network-${var.region}-ipam-pool"]
  }
}

data "aws_vpc_ipam_pool_cidrs" "network_cidrs" {
  provider     = aws.network-services
  ipam_pool_id = data.aws_vpc_ipam_pool.network.id
}

# IPAM Allocation for VPC only
resource "aws_vpc_ipam_pool_cidr_allocation" "vpc" {
  provider       = aws.network-services
  ipam_pool_id   = data.aws_vpc_ipam_pool.application.id
  netmask_length = 24
}

locals {
  vpc_cidr = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr

  # Calculate subnet CIDRs within the IPAM-allocated VPC CIDR
  private_cidrs = [
    cidrsubnet(local.vpc_cidr, 3, 0), # /27 subnet (32 IPs) - KEEP EXISTING
    cidrsubnet(local.vpc_cidr, 3, 1), # /27 subnet (32 IPs) - KEEP EXISTING
    cidrsubnet(local.vpc_cidr, 3, 2)  # /27 subnet (32 IPs) - KEEP EXISTING
  ]

  database_cidrs = [
    cidrsubnet(local.vpc_cidr, 4, 8), # /28 subnet (16 IPs) - KEEP EXISTING
    cidrsubnet(local.vpc_cidr, 4, 9), # /28 subnet (16 IPs) - KEEP EXISTING
    cidrsubnet(local.vpc_cidr, 4, 10) # /28 subnet (16 IPs) - KEEP EXISTING
  ]

  # NEW: Transit subnets for CloudWAN attachment
  transit_cidrs = [
    cidrsubnet(local.vpc_cidr, 4, 11), # /28 subnet (16 IPs) - NEW
    cidrsubnet(local.vpc_cidr, 4, 12), # /28 subnet (16 IPs) - NEW
    cidrsubnet(local.vpc_cidr, 4, 13)  # /28 subnet (16 IPs) - NEW
  ]
}

# Create Application VPC using shared IPAM
module "application_vpc" {
  source = "../../modules/vpc"

  providers = {
    aws = aws.application
  }

  is_primary_region = true

  # Enable VPC module to create flow logs resources
  create_flow_log_resources = true
  flow_log_retention_days   = 7

  # CloudWAN Configuration - module creates attachment
  cloudwan_config = {
    enabled                 = true
    core_network_id         = data.aws_ssm_parameter.core_network_id.value
    core_network_account_id = var.network_services_account_id
    segment                 = "production"
    auto_accept             = true
  }

  # CloudWAN Routes - module creates routes after attachment
  cloudwan_routes = {
    private  = ["10.0.0.0/8", "0.0.0.0/0"]
    database = ["10.0.0.0/8"]
  }

  vpc_configuration = {
    name         = "${var.environment}-production-vpc"
    type         = "application"
    category     = "workload"
    cidr_block   = aws_vpc_ipam_pool_cidr_allocation.vpc.cidr
    region       = var.region
    account_type = "application"
    environment  = var.environment

    subnet_configuration = {
      private = {
        type               = "private"
        cidr_blocks        = local.private_cidrs
        availability_zones = var.availability_zones
        route_table_config = {
          routes = [
            {
              destination = "10.0.0.0/8"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            },
            {
              destination = "0.0.0.0/0"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            }
          ]
        }
      }
      database = {
        type               = "database"
        cidr_blocks        = local.database_cidrs
        availability_zones = var.availability_zones
        route_table_config = {
          routes = [
            {
              destination = "10.0.0.0/8"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            },
            {
              destination = "0.0.0.0/0"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            }
          ]
        }
      }
      transit = {
        type               = "transit"
        cidr_blocks        = local.transit_cidrs
        availability_zones = var.availability_zones
        route_table_config = {
          routes = [
            {
              destination = "10.0.0.0/8"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            },
            {
              destination = "0.0.0.0/0"
              target_type = "cloudwan"
              target_id   = "arn:aws:networkmanager::${var.network_services_account_id}:core-network/${data.aws_ssm_parameter.core_network_id.value}"
            }
          ]
        }
      }
    }

    features = {
      enable_dns_hostnames    = true
      enable_dns_support      = true
      enable_flow_logs        = true # Enable flow logs (module creates resources)
      enable_nat_gateway      = false
      enable_internet_gateway = true # Required for CloudFront VPC Origins
      create_igw              = true # Create internet gateway
    }

    tags = {
      Name        = "${var.environment}-application-vpc"
      Environment = var.environment
      Type        = "application"
      Account     = var.application_account_id
    }
  }
}

# Deploy Web Application
module "web_application" {
  source = "../../modules/workload-application"

  providers = {
    aws = aws.application
  }

  environment      = var.environment
  application_name = "demo-web-app"

  vpc_id   = module.application_vpc.vpc_id
  vpc_cidr = module.application_vpc.vpc_cidr

  subnet_ids      = values(module.application_vpc.subnets["private"])
  route_table_ids = [for rt_id in values(module.application_vpc.route_table_ids) : rt_id]

  instance_config = {
    count         = 2
    instance_type = "t3.medium"
    key_name      = var.ssh_key_name
  }

  security_config = {
    ingress_rules = [
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        description = "HTTP from all internal networks"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        description = "SSH from all internal networks"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        from_port   = -1
        to_port     = -1
        protocol    = "icmp"
        description = "ICMP from all internal networks"
        cidr_blocks = ["10.0.0.0/8"]
      }
    ]
    egress_rules = [
      {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        description = "All outbound traffic"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }

  iam_config = {
    instance_profile_name = ""
  }

  user_data_config = {
    template_file = "${path.module}/templates/userdata-linux.sh"
    template_vars = {
      environment = var.environment
      hostname    = "${var.environment}-web-app"
      os_type     = "linux"
    }
  }

  vpc_endpoints_config = {
    enabled = true
    services = [
      "s3",
      "ec2",
      "ssm",
      "ssmmessages",
      "ec2messages",
      "logs",
      "monitoring"
    ]
  }

  tags = {
    Project     = "enterprise-network"
    Environment = var.environment
    Application = "demo-web-app"
    Account     = "application"
    Tier        = "web"
  }

  depends_on = [module.application_vpc]
}

# Internal Application Load Balancer
module "internal_alb" {
  source = "../../modules/alb"

  providers = {
    aws = aws.application
  }

  environment = var.environment
  vpc_id      = module.application_vpc.vpc_id
  subnet_ids  = values(module.application_vpc.subnets["private"])
  internal    = true

  target_group_target_type         = "instance"
  health_check_path                = "/health.html"
  health_check_matcher             = "200"
  health_check_interval            = 30
  health_check_timeout             = 5
  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
  target_group_port                = 80
  target_group_protocol            = "HTTP"

  tags = {
    Project     = "enterprise-network"
    Environment = var.environment
    Account     = "application"
    Purpose     = "cloudfront-vpc-origin"
  }

  depends_on = [module.web_application]
}

# Register application instances with ALB
resource "aws_lb_target_group_attachment" "app_instances" {
  provider         = aws.application
  count            = length(module.web_application.instance_ids)
  target_group_arn = module.internal_alb.default_target_group_arn
  target_id        = module.web_application.instance_ids[count.index]
  port             = 80
}

# Store ALB ARN in SSM for CloudFront VPC Origins
resource "aws_ssm_parameter" "alb_arn" {
  provider = aws.application
  name     = "/aft/network/alb/${var.environment}/arn"
  type     = "String"
  value    = module.internal_alb.alb_arn

  tags = {
    Name    = "ALB-ARN-${var.environment}"
    Purpose = "cloudfront-vpc-origin"
  }
}
