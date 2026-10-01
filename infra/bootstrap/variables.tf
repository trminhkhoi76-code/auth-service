variable "aws_region" {
  description = "AWS region for every resource of the project"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Prefix for resource names. Must match project_name in ../app"
  type        = string
  default     = "auth-service"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as \"owner/name\""
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like \"owner/name\"."
  }
}

variable "deploy_branch" {
  description = "Only workflows running on this branch may assume the deploy (write) role"
  type        = string
  default     = "main"
}

variable "ecr_keep_image_count" {
  description = "Number of images kept in ECR; older ones are expired"
  type        = number
  default     = 30
}
