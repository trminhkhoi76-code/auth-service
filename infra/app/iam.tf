# Role names must start with "<project>-ecs-": the GitHub deploy role is only allowed to
# manage roles with that prefix (see ../bootstrap/main.tf).

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Execution role: used by the ECS agent (pull image, write logs, read secrets)
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-ecs-execution-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SecureStrings use the AWS managed aws/ssm key, which needs no extra kms:Decrypt grant
data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.db_password.arn,
      aws_ssm_parameter.jwt_secret.arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-app-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

# --- Task role: assumed by the application itself. It calls no AWS API today;
# only ECS Exec needs permissions here.
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-ecs-task-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
}

data "aws_iam_policy_document" "task_exec" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_exec" {
  count = var.enable_execute_command ? 1 : 0

  name   = "ecs-exec"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec.json
}
