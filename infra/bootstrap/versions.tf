# Bootstrap stack — applied ONCE, locally, with admin credentials.
#
# Creates the resources that must exist before CI can run:
#   - S3 bucket holding the remote state of ../app
#   - ECR repository (CI pushes the image before ../app is applied)
#   - IAM roles assumed by GitHub Actions through OIDC
#
# Its own state is local (it creates the bucket the remote state would live in).
# Keep infra/bootstrap/terraform.tfstate somewhere safe, or migrate it into the bucket
# afterwards (see infra/README.md).
terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Stack     = "bootstrap"
      ManagedBy = "Terraform"
    }
  }
}
