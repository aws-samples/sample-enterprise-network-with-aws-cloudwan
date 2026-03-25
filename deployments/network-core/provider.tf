terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.28"
      configuration_aliases = [aws.network-services, aws.primary_region, aws.org-management, aws.management, aws.aft-management]
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.7.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  # Backend configuration - customize for your environment
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "network-core/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

