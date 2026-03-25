# Provider Configuration for Network Egress Module
# Deploying from Organization Management Account to Network Services Account

# Management Account Provider (where Terraform runs with org admin credentials)
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(var.tags, {
      ManagedBy    = "terraform"
      Module       = "network-egress"
      DeployedFrom = "org-management-account"
    })
  }
}

# Network Services Account Provider (where egress resources will be created)
provider "aws" {
  alias  = "network-services"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-egress"
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
      Module    = "network-egress"
      Account   = "network-services"
    })
  }
}

# Network Core Provider (same as network-services)
provider "aws" {
  alias  = "network-core"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-egress"
      Account   = "network-services"
    })
  }
}

# Network Inspection Provider (same as network-services)
provider "aws" {
  alias  = "network-inspection"
  region = var.primary_region

  assume_role {
    role_arn = "arn:aws:iam::${var.network_services_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-egress"
      Account   = "network-services"
    })
  }
}

# Security Account Provider (for reading security service configurations)
provider "aws" {
  alias  = "security"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = merge(var.tags, {
      ManagedBy = "terraform"
      Module    = "network-egress"
      Account   = "security"
    })
  }
}