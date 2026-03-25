
# Route Tables - using static keys
resource "aws_route_table" "private" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "private") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-private-rt"
    Type = "private"
  })
}

resource "aws_route_table" "public" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "public") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "public"
  })
}

resource "aws_route_table" "database" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "database") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-database-rt"
    Type = "database"
  })
}

resource "aws_route_table" "management" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "management") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-management-rt"
    Type = "management"
  })
}

resource "aws_route_table" "firewall" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "firewall") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-firewall-rt"
    Type = "firewall"
  })
}

resource "aws_route_table" "inspection" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "inspection") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-inspection-rt"
    Type = "inspection"
  })
}

resource "aws_route_table" "endpoints" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "endpoints") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-endpoints-rt"
    Type = "endpoints"
  })
}

resource "aws_route_table" "proxy" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "proxy") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-proxy-rt"
    Type = "proxy"
  })
}

resource "aws_route_table" "transit" {
  count = contains(keys(var.vpc_configuration.subnet_configuration), "transit") ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.vpc_tags, {
    Name = "${local.name_prefix}-transit-rt"
    Type = "transit"
  })
}

# Combine all route tables into a map for reference
locals {
  route_tables = merge(
    contains(keys(var.vpc_configuration.subnet_configuration), "private") ? { "private" = aws_route_table.private[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "public") ? { "public" = aws_route_table.public[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "database") ? { "database" = aws_route_table.database[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "transit") ? { "transit" = aws_route_table.transit[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "management") ? { "management" = aws_route_table.management[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "firewall") ? { "firewall" = aws_route_table.firewall[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "inspection") ? { "inspection" = aws_route_table.inspection[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "endpoints") ? { "endpoints" = aws_route_table.endpoints[0] } : {},
    contains(keys(var.vpc_configuration.subnet_configuration), "proxy") ? { "proxy" = aws_route_table.proxy[0] } : {}
  )
}

# Static route definitions (known at plan time) - excluding placeholders
locals {
  static_routes = merge([
    for subnet_key, rt_config in local.route_table_configs : {
      for idx, route in rt_config.routes : "${subnet_key}-${idx}" => {
        subnet_key  = subnet_key
        destination = route.destination
        target_type = route.target_type
        target_id   = route.target_id
      }
      # Only create routes that need explicit route resources and are not placeholders
      if route.target_type != "cloudwan" &&
      route.target_id != "gwlb-endpoint-placeholder" &&
      route.target_type != "local" &&
      route.target_id != null &&
      route.target_id != "" &&
      route.target_id != "igw-placeholder" &&
      route.target_id != "nat-placeholder"
    }
  ]...)

  # Separate handling for placeholder routes to avoid circular dependencies
  placeholder_routes = merge([
    for subnet_key, rt_config in local.route_table_configs : {
      for idx, route in rt_config.routes : "${subnet_key}-${idx}" => {
        subnet_key  = subnet_key
        destination = route.destination
        target_type = route.target_type
        target_id   = route.target_id
      }
      # Only include placeholder routes
      if(route.target_id == "igw-placeholder" || route.target_id == "nat-placeholder") &&
      route.target_type != "local"
    }
  ]...)
}

resource "aws_route" "main" {
  for_each = try(nonsensitive(local.static_routes), local.static_routes)

  route_table_id         = local.route_tables[each.value.subnet_key].id
  destination_cidr_block = each.value.destination

  # Target type routing - only set one target type per route
  gateway_id           = each.value.target_type == "igw" || each.value.target_type == "internet_gateway" ? each.value.target_id : null
  nat_gateway_id       = each.value.target_type == "nat" || each.value.target_type == "nat_gateway" ? each.value.target_id : null
  transit_gateway_id   = each.value.target_type == "tgw" || each.value.target_type == "transit_gateway" ? each.value.target_id : null
  network_interface_id = each.value.target_type == "eni" || each.value.target_type == "network_interface" ? each.value.target_id : null
  vpc_endpoint_id      = contains(["endpoint", "vpc_endpoint", "gateway_load_balancer_endpoint"], each.value.target_type) ? each.value.target_id : null
  core_network_arn     = each.value.target_type == "core_network" ? each.value.target_id : null
}

# Separate route resources for placeholder routes to avoid circular dependencies
resource "aws_route" "internet_gateway" {
  for_each = try(nonsensitive({
    for route_key, route in local.placeholder_routes : route_key => route
    if route.target_id == "igw-placeholder"
    }), {
    for route_key, route in local.placeholder_routes : route_key => route
    if route.target_id == "igw-placeholder"
  })

  route_table_id         = local.route_tables[each.value.subnet_key].id
  destination_cidr_block = each.value.destination
  gateway_id             = aws_internet_gateway.main[0].id

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway routes - ENABLED for management and transit subnet egress
resource "aws_route" "nat_gateway" {
  for_each = var.vpc_configuration.features.enable_nat_gateway && length(aws_nat_gateway.main) > 0 ? try(nonsensitive({
    for route_key, route in local.placeholder_routes : route_key => route
    if route.target_id == "nat-placeholder"
    }), {
    for route_key, route in local.placeholder_routes : route_key => route
    if route.target_id == "nat-placeholder"
  }) : {}

  route_table_id         = local.route_tables[each.value.subnet_key].id
  destination_cidr_block = each.value.destination
  nat_gateway_id         = aws_nat_gateway.main[0].id

  depends_on = [aws_nat_gateway.main]
}

# CloudWAN routes - Create routes to Core Network ARN after attachment
# These routes are created AFTER CloudWAN attachment to avoid circular dependencies
locals {
  # Build CloudWAN routes map: subnet_type-cidr => {subnet_type, cidr, core_network_arn}
  cloudwan_routes_map = var.cloudwan_config.enabled ? merge([
    for subnet_type, cidrs in var.cloudwan_routes : {
      for cidr in cidrs : "${subnet_type}-${replace(cidr, "/", "_")}" => {
        subnet_type      = subnet_type
        cidr             = cidr
        core_network_arn = "arn:aws:networkmanager::${var.cloudwan_config.core_network_account_id}:core-network/${var.cloudwan_config.core_network_id}"
      }
    }
  ]...) : {}
}

resource "aws_route" "cloudwan" {
  for_each = local.cloudwan_routes_map

  route_table_id         = local.route_tables[each.value.subnet_type].id
  destination_cidr_block = each.value.cidr
  core_network_arn       = each.value.core_network_arn

  depends_on = [
    aws_networkmanager_vpc_attachment.main,
    aws_route_table_association.main
  ]
}

# NOTE: CloudWAN routes are created AFTER VPC attachment to Core Network
# The depends_on ensures proper ordering: VPC → Subnets → Attachment → Routes

# Route Table Associations - simplified
resource "aws_route_table_association" "main" {
  for_each = aws_subnet.subnets

  subnet_id      = each.value.id
  route_table_id = local.route_tables[split("-", each.key)[0]].id

  depends_on = [
    aws_subnet.subnets
  ]
}
