data "aws_region" "current" {}

# Data source for GWLB service names from SSM parameters
data "aws_ssm_parameter" "gwlb_services" {
  for_each = {
    for idx, endpoint in var.gwlb_endpoints :
    endpoint.name => endpoint
    if endpoint.ssm_parameter_name != null
  }

  name = each.value.ssm_parameter_name
}

locals {
  # Auto-generate endpoints from service names
  endpoints_to_create = {
    for service in var.endpoint_services : service => {
      service             = service
      service_type        = contains(["s3", "dynamodb"], service) ? "Gateway" : "Interface"
      private_dns_enabled = contains(["s3", "dynamodb"], service) ? false : true
      policy              = null # Handled by template system
      security_group_ids  = [var.security_group_id]
    }
  }

  interface_endpoints = {
    for name, endpoint in local.endpoints_to_create :
    name => endpoint
    if endpoint.service_type == "Interface"
  }

  gateway_endpoints = {
    for name, endpoint in local.endpoints_to_create :
    name => endpoint
    if endpoint.service_type == "Gateway"
  }

  # Auto-source endpoint policies from templates
  endpoint_policies = {
    for name, endpoint in local.endpoints_to_create : name => (
      fileexists("${path.module}/policies/${lower(endpoint.service_type)}/${endpoint.service}.json.tpl") ?
      templatefile(
        "${path.module}/policies/${lower(endpoint.service_type)}/${endpoint.service}.json.tpl",
        {
          vpc_id     = var.vpc_id
          region     = var.region
          service    = endpoint.service
          aws_region = data.aws_region.current.id
        }
      ) :
      templatefile(
        "${path.module}/policies/${lower(endpoint.service_type)}/default.json.tpl",
        {
          vpc_id     = var.vpc_id
          region     = var.region
          service    = endpoint.service
          aws_region = data.aws_region.current.id
        }
      )
    )
  }

  # New local for predictable gateway route table associations
  gateway_route_table_associations = flatten([
    for endpoint_name, endpoint in local.gateway_endpoints : [
      for rt_id in var.route_table_ids : {
        key            = "${endpoint_name}-${rt_id}"
        endpoint_name  = endpoint_name
        route_table_id = rt_id
      }
    ]
  ])

  # GWLB endpoints with resolved service names
  gwlb_endpoints_resolved = {
    for endpoint in var.gwlb_endpoints : endpoint.name => {
      name = endpoint.name
      service_name = (
        endpoint.service_name != null ? endpoint.service_name :
        endpoint.ssm_json_path != null ?
        jsondecode(data.aws_ssm_parameter.gwlb_services[endpoint.name].value)[split(".", endpoint.ssm_json_path)[0]][split(".", endpoint.ssm_json_path)[1]][split(".", endpoint.ssm_json_path)[2]] :
        data.aws_ssm_parameter.gwlb_services[endpoint.name].value
      )
      subnet_ids = endpoint.subnet_ids
    }
  }
}



resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(var.subnet_ids)
  private_dns_enabled = each.value.private_dns_enabled

  security_group_ids = each.value.security_group_ids

  policy = local.endpoint_policies[each.key]

  tags = merge(var.tags, {
    Name = "vpce-${each.value.service}"
  })

  lifecycle {
    create_before_destroy = false
  }
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type = "Gateway"

  policy = local.endpoint_policies[each.key]

  tags = merge(var.tags, {
    Name = "vpce-${each.value.service}"
  })
}

# Gateway endpoint route table associations
# Simplified - remove the data source lookup that causes for_each issues
resource "aws_vpc_endpoint_route_table_association" "gateway" {
  count = length(local.gateway_route_table_associations)

  vpc_endpoint_id = aws_vpc_endpoint.gateway[local.gateway_route_table_associations[count.index].endpoint_name].id
  route_table_id  = local.gateway_route_table_associations[count.index].route_table_id

  lifecycle {
    ignore_changes = [
      # Ignore changes if route already exists
      vpc_endpoint_id,
      route_table_id
    ]
  }
}

# GWLB VPC Endpoints
resource "aws_vpc_endpoint" "gwlb" {
  for_each = local.gwlb_endpoints_resolved

  vpc_id            = var.vpc_id
  service_name      = each.value.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = each.value.subnet_ids

  tags = merge(var.tags, {
    Name = each.value.name
    Type = "GatewayLoadBalancer"
  })

  lifecycle {
    create_before_destroy = false
  }
}



