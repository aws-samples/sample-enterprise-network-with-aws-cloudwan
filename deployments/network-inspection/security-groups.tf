# Security Group for Inspection VPC - Default Deny
resource "aws_security_group" "inspection_default" {
  provider    = aws.security
  name_prefix = "${local.name_prefix}-inspection-default-"
  description = "Default security group for inspection VPC - deny all by default"
  vpc_id      = module.inspection_vpc.vpc_id

  # No ingress rules - deny all inbound by default

  # Allow outbound to CloudWAN for routing
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"] # Organization CIDR
    description = "Allow outbound to organization networks"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-inspection-default-sg"
    Type = "inspection-default"
  })
}

# Security Group for Shared Services Access (conditional)
resource "aws_security_group" "allow_shared_services" {
  provider    = aws.security
  name_prefix = "${local.name_prefix}-allow-shared-services-"
  description = "Allow access to shared services"
  vpc_id      = module.inspection_vpc.vpc_id

  # Allow traffic to/from SharedServices segment
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.74.92.0/22"] # SharedServices CIDR
    description = "Allow inbound from SharedServices"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.74.92.0/22"] # SharedServices CIDR
    description = "Allow outbound to SharedServices"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-allow-shared-services-sg"
    Type = "shared-services-access"
  })
}

# Security Group for Hybrid Cloud Access
resource "aws_security_group" "allow_hybrid" {
  provider    = aws.security
  name_prefix = "${local.name_prefix}-allow-hybrid-"
  description = "Allow access to hybrid cloud resources"
  vpc_id      = module.inspection_vpc.vpc_id

  # Allow traffic to/from on-premises networks
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16", "172.16.0.0/12"] # On-premises CIDRs
    description = "Allow inbound from on-premises"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16", "172.16.0.0/12"] # On-premises CIDRs
    description = "Allow outbound to on-premises"
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-allow-hybrid-sg"
    Type = "hybrid-access"
  })
}

# Security Group to Block Workload-to-Workload (Applied to workload VPCs)
resource "aws_security_group" "block_workload_lateral" {
  provider    = aws.security
  name_prefix = "${local.name_prefix}-block-workload-lateral-"
  description = "Block lateral movement between workload segments"
  vpc_id      = module.inspection_vpc.vpc_id

  # Explicitly deny workload-to-workload traffic
  # This would be applied to workload VPCs via CloudWAN policies

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-block-workload-lateral-sg"
    Type = "workload-isolation"
  })
}

# VPC Flow Logs are now managed by the VPC module
# No need for standalone resources here
