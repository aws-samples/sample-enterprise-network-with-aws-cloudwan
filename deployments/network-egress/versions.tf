terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
      configuration_aliases = [
        aws.primary_region,
        aws.org-management,
        aws.management,
        aws.aft-management,
        aws.network-core,
        aws.network-inspection
      ]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }
  }
}