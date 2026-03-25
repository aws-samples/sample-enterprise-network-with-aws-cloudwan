module "network_core" {
  source = "../"

  providers = {
    aws                = aws
    aws.primary_region = aws.primary_region
    aws.org-management = aws.org-management
  }

  environment           = var.environment
  region                = var.region
  primary_region        = var.primary_region
  enabled_regions       = var.enabled_regions
  pool_configuration    = var.pool_configuration
  regional_config       = var.regional_config
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  subnet_configuration  = var.subnet_configuration
  vpc_endpoints         = var.vpc_endpoints
  resolver_config       = var.resolver_config
  private_hosted_zones  = var.private_hosted_zones
  external_hosted_zones = var.external_hosted_zones
  enable_ram_sharing    = var.enable_ram_sharing
  enable_logging        = var.enable_logging
  log_retention_days    = var.log_retention_days
  tags                  = var.tags
}

