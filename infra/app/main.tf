# =============================================================================
# auth-service — application stack
#
#   Internet ──► ALB (public subnets, :80 / :443)
#                 │  target group /actuator/health/readiness
#                 ▼
#             ECS Fargate service (public subnets + public IP, no NAT Gateway)
#                 │  SG: only the ALB may reach :8080
#                 ▼
#             RDS MySQL 8.4 (private subnets, no internet route)
#                 SG: only the ECS tasks may reach :3306
#
# Tasks sit in public subnets so they reach ECR / SSM / CloudWatch without a NAT
# Gateway (~$35+/month saved); inbound traffic is still limited to the ALB.
# Secrets (DB password, JWT secret) live in SSM SecureString and are injected by ECS.
# =============================================================================

locals {
  name           = "${var.project_name}-${var.environment}"
  container_name = var.project_name
  azs            = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  https_enabled  = var.certificate_arn != ""
  image          = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "app" {
  name = var.project_name
}
