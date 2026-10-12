# IAM execution role used by ECS/Fargate
resource "aws_iam_role" "cloudcart_ecs_task_execution_role" {
  name = "cloudcart-ecs-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-ECS-Task-Execution-Role"
    }
  )
}

# Grants the execution role standard permissions required by ECS tasks
resource "aws_iam_role_policy_attachment" "cloudcart_ecs_task_execution_policy" {
  role       = aws_iam_role.cloudcart_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM policy for retrieving the CloudCart database secret
resource "aws_iam_policy" "cloudcart_ecs_secrets" {
  name   = "cloudcart-ecs-secrets"
  policy = data.aws_iam_policy_document.cloudcart_ecs_secrets.json
}

# Attach database secret access to the ECS execution role
resource "aws_iam_role_policy_attachment" "cloudcart_ecs_secrets" {
  role       = aws_iam_role.cloudcart_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.cloudcart_ecs_secrets.arn
}

resource "aws_iam_role" "github_actions_ecr" {
  name = "cloudcart-github-actions-ecr-role"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "cloudcart-github-actions-ecr-role"
    }
  )
}

# Create the IAM policy
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "cloudcart-github-actions-ecr-policy"
  description = "Allows GitHub Actions to push CloudCart Docker images to ECR"

  policy = data.aws_iam_policy_document.github_actions_ecr.json
}

# Attach the policy to the GitHub Actions IAM role
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# ECS deployment permissions for GitHub Actions
resource "aws_iam_policy" "github_actions_ecs" {
  name        = "cloudcart-github-actions-ecs-policy"
  description = "Allows GitHub Actions to deploy CloudCart services to ECS"

  policy = data.aws_iam_policy_document.github_actions_ecs.json

}

# Attach the policy to the GitHub Actions IAM role
resource "aws_iam_role_policy_attachment" "github_actions_ecs" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecs.arn
}