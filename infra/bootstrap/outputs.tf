output "state_bucket" {
  description = "Put this in ../app/env/<env>.s3.tfbackend"
  value       = aws_s3_bucket.tfstate.bucket
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "github_plan_role_arn" {
  description = "GitHub variable AWS_PLAN_ROLE_ARN"
  value       = aws_iam_role.github_plan.arn
}

output "github_deploy_role_arn" {
  description = "GitHub variable AWS_DEPLOY_ROLE_ARN"
  value       = aws_iam_role.github_deploy.arn
}
