# ECS cluster for CloudCart application services
resource "aws_ecs_cluster" "cloudcart_cluster" {
  name = "cloudcart-cluster"

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-ECS-Cluster"
    }
  )
}

# Fargate task definition for the Product Service
resource "aws_ecs_task_definition" "cloudcart_product_service" {
  family                   = "cloudcart-product-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.cloudcart_ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "product-service"
      image     = "${aws_ecr_repository.cloudcart_product_service.repository_url}:latest"
      essential = true

      # Non-sensitive database configuration provided directly to the container.
      # The RDS endpoint is created by AWS when the database is provisioned.
      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.cloudcart_postgres.address
        },
        {
          name  = "DB_PORT"
          value = tostring(aws_db_instance.cloudcart_postgres.port)
        },
        {
          name  = "DB_NAME"
          value = "cloudcart"
        }
      ]

      # Sensitive database credentials are injected from the RDS-managed
      # Secrets Manager secret instead of being stored in the task definition.
      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_db_instance.cloudcart_postgres.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.cloudcart_postgres.master_user_secret[0].secret_arn}:password::"
        }
      ]

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cloudcart_product_service.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "product-service"
        }
      }
    }
  ])
}

# ECS service that runs and maintains the Product Service
resource "aws_ecs_service" "cloudcart_product_service" {
  name            = "cloudcart-product-service"
  cluster         = aws_ecs_cluster.cloudcart_cluster.id
  task_definition = aws_ecs_task_definition.cloudcart_product_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.cloudcart_product_service.arn
    container_name   = "product-service"
    container_port   = 8000
  }

  network_configuration {
    subnets = [
      aws_subnet.cloudcart_private_app_subnet_a.id,
      aws_subnet.cloudcart_private_app_subnet_b.id
    ]

    security_groups = [
      aws_security_group.cloudcart_ecs_sg.id
    ]

    assign_public_ip = false
  }
}