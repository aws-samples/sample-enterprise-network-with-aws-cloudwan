locals {
  name_prefix = var.vpc_configuration.name

  vpc_tags = merge(
    var.vpc_configuration.tags,
    {
      Name        = var.vpc_configuration.name
      Environment = var.vpc_configuration.environment
      Category    = var.vpc_configuration.category
      Type        = var.vpc_configuration.type
      ManagedBy   = "terraform"
    }
  )

  # Create unique keys for subnet configurations using subnet_key
  subnet_configs_by_type_and_az = {
    for subnet_key, subnet in var.vpc_configuration.subnet_configuration : subnet_key => {
      for idx, az in subnet.availability_zones : az => {
        cidr_block = subnet.cidr_blocks[idx]
        public_ip  = try(subnet.public_ip, false)
        type       = subnet.type
        tags = merge(
          var.vpc_configuration.tags,
          {
            Name = "${local.name_prefix}-${subnet.type}-${az}"
            Type = subnet.type
            AZ   = az
          }
        )
      }
    }
  }

  # Organize subnets by type
  subnet_types = distinct([
    for subnet in values(var.vpc_configuration.subnet_configuration) : subnet.type
  ])

  # Route table configurations with static keys to avoid sensitive value issues
  # Create non-sensitive route table configurations
  route_table_configs = {
    for subnet_key, subnet in var.vpc_configuration.subnet_configuration :
    subnet_key => {
      type = subnet.type
      # Create static route configuration to avoid sensitive values in for_each
      routes = [
        for route in subnet.route_table_config.routes : {
          destination = route.destination
          target_type = route.target_type
          # Use placeholder for CloudWAN routes to avoid sensitive values
          target_id = route.target_type == "cloudwan" ? "cloudwan-placeholder" : route.target_id
        }
      ]
    } if subnet.route_table_config != null
  }

  # Transit subnets for CloudWAN attachments
  transit_subnets = {
    for subnet_key, subnet in aws_subnet.subnets :
    subnet.availability_zone => subnet.id
    if split("-", subnet_key)[0] == "transit"
  }
}

