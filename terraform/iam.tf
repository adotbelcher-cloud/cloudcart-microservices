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