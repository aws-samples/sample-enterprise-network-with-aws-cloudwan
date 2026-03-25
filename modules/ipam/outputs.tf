output "ipam_details" {
  description = "IPAM details including all pools and their IDs"
  value = {
    ipam_id = aws_vpc_ipam.main.id
    pools = {
      global = {
        id   = aws_vpc_ipam_pool.global.id
        arn  = aws_vpc_ipam_pool.global.arn
        cidr = aws_vpc_ipam_pool_cidr.global.cidr
      }
      core = {
        id   = aws_vpc_ipam_pool.core.id
        arn  = aws_vpc_ipam_pool.core.arn
        cidr = aws_vpc_ipam_pool_cidr.core.cidr
        regional_pools = {
          for region, pool in aws_vpc_ipam_pool.core_regional : region => {
            id   = pool.id
            arn  = pool.arn
            cidr = aws_vpc_ipam_pool_cidr.core_regional[region].cidr
          }
        }
      }
      network = {
        id   = aws_vpc_ipam_pool.network.id
        arn  = aws_vpc_ipam_pool.network.arn
        cidr = aws_vpc_ipam_pool_cidr.network.cidr
        regional_pools = {
          for region, pool in aws_vpc_ipam_pool.network_regional : region => {
            id   = pool.id
            arn  = pool.arn
            cidr = aws_vpc_ipam_pool_cidr.network_regional[region].cidr
          }
        }
      }
      workload = {
        id   = aws_vpc_ipam_pool.workload.id
        arn  = aws_vpc_ipam_pool.workload.arn
        cidr = aws_vpc_ipam_pool_cidr.workload.cidr
        regional_pools = {
          for region, pool in aws_vpc_ipam_pool.workload_regional : region => {
            id   = pool.id
            arn  = pool.arn
            cidr = aws_vpc_ipam_pool_cidr.workload_regional[region].cidr
          }
        }
      }
    }
  }
  # Ensure this output waits for all regional pool CIDRs
  depends_on = [
    aws_vpc_ipam_pool_cidr.core_regional,
    aws_vpc_ipam_pool_cidr.network_regional,
    aws_vpc_ipam_pool_cidr.workload_regional
  ]
}

output "regional_pools_ready" {
  description = "Indicates that regional pools have CIDRs allocated and are ready for use"
  value = {
    core_pools = {
      for region, cidr_resource in aws_vpc_ipam_pool_cidr.core_regional : region => {
        pool_id = aws_vpc_ipam_pool.core_regional[region].id
        cidr    = cidr_resource.cidr
      }
    }
    network_pools = {
      for region, cidr_resource in aws_vpc_ipam_pool_cidr.network_regional : region => {
        pool_id = aws_vpc_ipam_pool.network_regional[region].id
        cidr    = cidr_resource.cidr
      }
    }
    workload_pools = {
      for region, cidr_resource in aws_vpc_ipam_pool_cidr.workload_regional : region => {
        pool_id = aws_vpc_ipam_pool.workload_regional[region].id
        cidr    = cidr_resource.cidr
      }
    }
  }
}

output "ram_sharing" {
  description = "RAM sharing details"
  value = var.enable_ram_sharing ? {
    resource_share_arn  = aws_ram_resource_share.ipam_pools[0].arn
    resource_share_name = aws_ram_resource_share.ipam_pools[0].name
    shared_pool_arns    = local.shared_pool_arns
  } : null
}