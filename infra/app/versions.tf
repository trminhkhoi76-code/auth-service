terraform {
  # >= 1.11: ephemeral resources + write-only attributes keep generated secrets out of the state
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # Partial config: terraform init -backend-config=env/<env>.s3.tfbackend
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Stack       = "app"
      ManagedBy   = "Terraform"
    }
  }
}
