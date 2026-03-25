# Provider Configuration for Network Inspection Module
# Deploying from Organization Management Account to Security Account

# Management Account Provider (where Terraform runs with org admin credentials)
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy    = "terraform"
      Module       = "network-inspection"
      DeployedFrom = "org-management-account"
    })
  }
}

# Security Account Provider (where inspection resources will be created)
provider "aws" {
  alias  = "security"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-inspection"
      Account   = "security"
    })
  }
}

# Network Services Account Provider (for reading IPAM pools and CloudWAN)
provider "aws" {
  alias  = "network-services"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_core_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-inspection"
      Account   = "network-services"
    })
  }
}

# Network Core Provider (same as network-services)
provider "aws" {
  alias  = "network-core"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_core_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-inspection"
      Account   = "network-services"
    })
  }
}