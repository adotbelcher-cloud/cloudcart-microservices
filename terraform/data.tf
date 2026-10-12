
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

# Allows GitHub Actions to assume the ECR role via OIDC
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActions"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:adotbelcher-cloud@317771272/cloudcart-microservices@1373997224:ref:refs/heads/main"
      ]
    }
  }
}

# ECR permissions for GitHub Actions
data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid    = "AllowECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudCartImagePush"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]

    resources = [
      aws_ecr_repository.cloudcart_product_service.arn,
      aws_ecr_repository.cloudcart_order_service.arn
    ]
  }
}

# ECS deployment permissions for GitHub Actions
data "aws_iam_policy_document" "github_actions_ecs" {
  statement {
    sid    = "AllowRegisterTaskDefinition"
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition"
    ]

    resources = [
      "arn:aws:ecs:us-east-1:063562647105:task-definition/cloudcart-product-service:*",
      "arn:aws:ecs:us-east-1:063562647105:task-definition/cloudcart-order-service:*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = ["cloudcart-microservices"]
    }
  }

  statement {
    sid    = "AllowCloudCartServiceDeployments"
    effect = "Allow"

    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]

    resources = [
      "arn:aws:ecs:us-east-1:063562647105:service/cloudcart-cluster/cloudcart-product-service",
      "arn:aws:ecs:us-east-1:063562647105:service/cloudcart-cluster/cloudcart-order-service"
    ]
  }

  statement {
    sid    = "AllowCloudCartTaskDefinitionRead"
    effect = "Allow"

    actions = [
      "ecs:DescribeTaskDefinition"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowPassECSTaskExecutionRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.cloudcart_ecs_task_execution_role.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid    = "AllowTaskDefinitionTagging"
    effect = "Allow"

    actions = ["ecs:TagResource"]

    resources = [
      "arn:aws:ecs:us-east-1:063562647105:task-definition/cloudcart-product-service:*",
      "arn:aws:ecs:us-east-1:063562647105:task-definition/cloudcart-order-service:*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["RegisterTaskDefinition"]
    }
  }
}
