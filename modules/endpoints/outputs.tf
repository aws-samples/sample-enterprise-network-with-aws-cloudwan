output "endpoint_ids" {
  description = "Map of created endpoint names to their IDs"
  value = merge(
    { for name, endpoint in aws_vpc_endpoint.interface : name => endpoint.id },
    { for name, endpoint in aws_vpc_endpoint.gateway : name => endpoint.id },
    { for name, endpoint in aws_vpc_endpoint.gwlb : name => endpoint.id }
  )
}

output "endpoint_dns_entries" {
  description = "DNS entries for created interface endpoints"
  value = {
    for name, endpoint in aws_vpc_endpoint.interface : name => endpoint.dns_entry
  }
}

output "gwlb_endpoints" {
  description = "GWLB endpoint details"
  value = {
    for name, endpoint in aws_vpc_endpoint.gwlb : name => {
      id       = endpoint.id
      arn      = endpoint.arn
      dns_name = length(endpoint.dns_entry) > 0 ? endpoint.dns_entry[0].dns_name : ""
    }
  }
}

output "endpoint_dns_data" {
  description = "DNS data for endpoints to be used by DNS module"
  value = {
    interface_endpoints = {
      for name, endpoint in aws_vpc_endpoint.interface : name => {
        service_name          = endpoint.service_name
        service               = local.interface_endpoints[name].service
        region                = var.region
        dns_name              = length(endpoint.dns_entry) > 0 ? endpoint.dns_entry[0].dns_name : ""
        hosted_zone_id        = length(endpoint.dns_entry) > 0 ? endpoint.dns_entry[0].hosted_zone_id : ""
        ip_addresses          = [] # Will be populated by DNS module using network_interface_ids
        network_interface_ids = endpoint.network_interface_ids
      }
    }
    gateway_endpoints = {
      for name, endpoint in aws_vpc_endpoint.gateway : name => {
        service_name   = endpoint.service_name
        service        = local.gateway_endpoints[name].service
        region         = var.region
        prefix_list_id = endpoint.prefix_list_id
      }
    }
    gwlb_endpoints = {
      for name, endpoint in aws_vpc_endpoint.gwlb : name => {
        service_name = endpoint.service_name
        dns_name     = length(endpoint.dns_entry) > 0 ? endpoint.dns_entry[0].dns_name : ""
      }
    }
  }
}

output "debug" {
  value = {
    interface_endpoints = local.interface_endpoints
    gateway_endpoints   = local.gateway_endpoints
    gwlb_endpoints      = local.gwlb_endpoints_resolved
    region              = var.region
    vpc_id              = var.vpc_id
    subnet_ids          = var.subnet_ids
  }
}

# RAM sharing outputs removed - VPC endpoints cannot be RAM shared