terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "primary_region"
  region = var.primary_region
}

provider "aws" {
  alias  = "org-management"
  region = var.primary_region
  assume_role {
    role_arn = var.management_account_role_arn
  }
}

