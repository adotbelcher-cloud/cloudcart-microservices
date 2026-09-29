# Discover available Availability Zones in the configured AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# Allows ECS tasks to assume the task execution role
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Allows ECS to retrieve the RDS-managed database secret
data "aws_iam_policy_document" "cloudcart_ecs_secrets" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_db_instance.cloudcart_postgres.master_user_secret[0].secret_arn
    ]
  }
}