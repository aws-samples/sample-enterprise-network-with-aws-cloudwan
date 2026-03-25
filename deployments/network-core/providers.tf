# Provider Configurations for Network Core Module
# Designed for deployment from Organization Management Account with role assumptions

# Organization Management Account Provider (where Terraform runs)
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy    = "terraform"
      Module       = "network-core"
      DeployedFrom = "management-account"
    })
  }
}

# Network Services Account Provider (where IPAM resources will be created)
provider "aws" {
  alias  = "network-services"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-core"
      Account   = "network-services"
    })
  }
}

# Primary Region Provider (for network services account)
provider "aws" {
  alias  = "primary_region"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-core"
      Account   = "network-services"
    })
  }
}

# Organization Management Account Provider (same as default, no role assumption needed)
provider "aws" {
  alias  = "org-management"
  region = var.primary_region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-core"
      Account   = "org-management"
    })
  }
}

# Management Account Provider (alias for org-management)
provider "aws" {
  alias  = "management"
  region = var.primary_region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-core"
      Account   = "management"
    })
  }
}

# AFT Management Account Provider (assume role to network services account for SSM storage)
provider "aws" {
  alias  = "aft-management"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-core"
      Account   = "network-services"
    })
  }
}