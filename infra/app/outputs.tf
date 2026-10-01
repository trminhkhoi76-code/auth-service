output "app_url" {
  value = "${local.https_enabled ? "https" : "http"}://${aws_lb.this.dns_name}"
}

output "alb_dns_name" {
  description = "Point a CNAME/alias record here when using a custom domain"
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.app.arn
}

# Read by the PR plan job so the plan only shows infrastructure changes
output "image_tag" {
  value = var.image_tag
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "db_endpoint" {
  value = aws_db_instance.this.endpoint
}
