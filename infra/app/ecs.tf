resource "aws_ecs_cluster" "this" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = local.container_name
    image     = local.image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [
      { name = "SERVER_PORT", value = tostring(var.container_port) },
      { name = "DB_HOST", value = aws_db_instance.this.address },
      { name = "DB_PORT", value = tostring(aws_db_instance.this.port) },
      { name = "DB_NAME", value = var.db_name },
      { name = "DB_USERNAME", value = var.db_username },
      { name = "JWT_ACCESS_TOKEN_TTL", value = var.jwt_access_token_ttl },
      { name = "JWT_REFRESH_TOKEN_TTL", value = var.jwt_refresh_token_ttl },
    ]

    secrets = [
      { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
      { name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn },
    ]

    # Liveness only: a database outage must not make ECS kill otherwise healthy tasks
    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO /dev/null http://localhost:${var.container_port}/actuator/health/liveness || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 90
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "app" {
  name             = local.name
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.app.arn
  desired_count    = var.desired_count
  platform_version = "LATEST"

  capacity_provider_strategy {
    capacity_provider = var.use_fargate_spot ? "FARGATE_SPOT" : "FARGATE"
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true # reach ECR/SSM/Logs without a NAT Gateway
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # A release whose tasks never become healthy is rolled back to the previous task definition
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  enable_execute_command = var.enable_execute_command
  propagate_tags         = "SERVICE"

  # `terraform apply` returns only once the new tasks are healthy (or fails)
  wait_for_steady_state = true

  # Secrets do not change the task definition: redeploy explicitly when one is rotated
  force_new_deployment = true
  triggers = {
    secrets_version = "${var.db_password_version}-${var.jwt_secret_version}"
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.this,
    aws_iam_role_policy.execution_secrets,
  ]
}
