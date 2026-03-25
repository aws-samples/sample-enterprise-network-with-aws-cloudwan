# providers.tf
# module/providers.tf
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.0.0"
      configuration_aliases = [aws.primary_region, aws.org-management]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}

#provider "aws" {
#  region = var.primary_region
#}

#provider "aws" {
#  alias  = "primary_region"
#  region = var.primary_region
#}

#provider "aws" {
#  alias  = "org-management"
#  region = var.primary_region
#}

