# Network Firewall Route Management
# This file manages routes for Network Firewall integration

# Transit subnet routes → Network Firewall
# Routes traffic from CloudWAN through firewall for inspection
resource "aws_route" "transit_to_firewall" {
  for_each = var.manage_routes && contains(keys(var.route_table_ids), "transit") ? {
    for idx, route in var.transit_routes :
    "${route.destination_cidr_block}" => route
  } : {}

  route_table_id         = var.route_table_ids["transit"]
  destination_cidr_block = each.value.destination_cidr_block
  vpc_endpoint_id        = element(local.firewall_endpoint_ids_list, 0)

  depends_on = [aws_networkfirewall_firewall.main]
}

# Firewall subnet routes → CloudWAN/NAT Gateway
# Routes traffic after inspection to destination
resource "aws_route" "firewall_to_target" {
  for_each = var.manage_routes && contains(keys(var.route_table_ids), "firewall") ? {
    for idx, route in var.firewall_routes :
    "${route.destination_cidr_block}-${route.target_type}" => route
  } : {}

  route_table_id         = var.route_table_ids["firewall"]
  destination_cidr_block = each.value.destination_cidr_block

  # Dynamic target based on type
  core_network_arn = each.value.target_type == "cloudwan" ? var.core_network_arn : null
  nat_gateway_id   = each.value.target_type == "nat_gateway" ? var.nat_gateway_id : null
  gateway_id       = each.value.target_type == "internet_gateway" ? each.value.target_id : null

  depends_on = [aws_networkfirewall_firewall.main]
}

# Public subnet return routes → Network Firewall
# Fixes asymmetric routing for return traffic
resource "aws_route" "public_return_to_firewall" {
  for_each = var.manage_routes && contains(keys(var.route_table_ids), "public") ? {
    for idx, route in var.public_return_routes :
    "${route.destination_cidr_block}" => route
  } : {}

  route_table_id         = var.route_table_ids["public"]
  destination_cidr_block = each.value.destination_cidr_block
  vpc_endpoint_id        = element(local.firewall_endpoint_ids_list, 0)

  depends_on = [aws_networkfirewall_firewall.main]
}
