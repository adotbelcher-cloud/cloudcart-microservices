# CloudWatch log group for the Product Service
resource "aws_cloudwatch_log_group" "cloudcart_product_service" {
  name              = "/ecs/cloudcart-product-service"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Product-Service-Logs"
    }
  )
}

# CloudWatch log group for the Order Service
resource "aws_cloudwatch_log_group" "cloudcart_order_service" {
  name              = "/ecs/cloudcart-order-service"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Order-Service-Logs"
    }
  )
}

# CloudWatch dashboard for CloudCart ECS services
resource "aws_cloudwatch_dashboard" "cloudcart_dashboard" {
  dashboard_name = "CloudCart-Infrastructure"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS CPU Utilization"
          region = "us-east-1"
          period = 300
          stat   = "Average"
          metrics = [
            [
              "AWS/ECS", "CPUUtilization",
              "ClusterName", aws_ecs_cluster.cloudcart_cluster.name,
              "ServiceName", aws_ecs_service.cloudcart_product_service.name
            ],
            [
              "AWS/ECS", "CPUUtilization",
              "ClusterName", aws_ecs_cluster.cloudcart_cluster.name,
              "ServiceName", aws_ecs_service.cloudcart_order_service.name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "ECS Memory Utilization"
          region = "us-east-1"
          period = 300
          stat   = "Average"
          metrics = [
            [
              "AWS/ECS", "MemoryUtilization",
              "ClusterName", aws_ecs_cluster.cloudcart_cluster.name,
              "ServiceName", aws_ecs_service.cloudcart_product_service.name
            ],
            [
              "AWS/ECS", "MemoryUtilization",
              "ClusterName", aws_ecs_cluster.cloudcart_cluster.name,
              "ServiceName", aws_ecs_service.cloudcart_order_service.name
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ALB Healthy Targets"
          region = "us-east-1"
          period = 60
          stat   = "Minimum"

          metrics = [
            [
              "AWS/ApplicationELB", "HealthyHostCount",
              "TargetGroup", aws_lb_target_group.cloudcart_product_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ],
            [
              "AWS/ApplicationELB", "HealthyHostCount",
              "TargetGroup", aws_lb_target_group.cloudcart_order_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target HTTP 5xx Errors"
          region = "us-east-1"
          period = 60
          stat   = "Sum"

          metrics = [
            [
              "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count",
              "TargetGroup", aws_lb_target_group.cloudcart_product_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ],
            [
              "AWS/ApplicationELB", "HTTPCode_Target_5XX_Count",
              "TargetGroup", aws_lb_target_group.cloudcart_order_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target Response Time"
          region = "us-east-1"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          yAxis = {
            left = {
              label = "Response Time (seconds)"
              min   = 0
            }
          }

          metrics = [
            [
              "AWS/ApplicationELB", "TargetResponseTime",
              "TargetGroup", aws_lb_target_group.cloudcart_product_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ],
            [
              "AWS/ApplicationELB", "TargetResponseTime",
              "TargetGroup", aws_lb_target_group.cloudcart_order_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target Request Count"
          region = "us-east-1"
          period = 60
          stat   = "Sum"

          metrics = [
            [
              "AWS/ApplicationELB", "RequestCount",
              "TargetGroup", aws_lb_target_group.cloudcart_product_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ],
            [
              "AWS/ApplicationELB", "RequestCount",
              "TargetGroup", aws_lb_target_group.cloudcart_order_service.arn_suffix,
              "LoadBalancer", aws_lb.cloudcart_alb.arn_suffix
            ]
          ]
        }
      }
    ]
  })
}

# Alarm when Product Service has no healthy ALB targets
resource "aws_cloudwatch_metric_alarm" "cloudcart_product_unhealthy" {
  alarm_name        = "CloudCart-Product-Service-Unhealthy"
  alarm_description = "Product Service has no healthy ALB targets"

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 1

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  period      = 60
  statistic   = "Minimum"

  dimensions = {
    TargetGroup  = aws_lb_target_group.cloudcart_product_service.arn_suffix
    LoadBalancer = aws_lb.cloudcart_alb.arn_suffix
  }

  treat_missing_data = "breaching"

  alarm_actions = [
    aws_sns_topic.cloudcart_alerts.arn
  ]

  ok_actions = [
    aws_sns_topic.cloudcart_alerts.arn
  ]

  tags = local.common_tags
}

# Alarm when Order Service has no healthy ALB targets
resource "aws_cloudwatch_metric_alarm" "cloudcart_order_unhealthy" {
  alarm_name        = "CloudCart-Order-Service-Unhealthy"
  alarm_description = "Order Service has no healthy ALB targets"

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 1

  namespace   = "AWS/ApplicationELB"
  metric_name = "HealthyHostCount"
  period      = 60
  statistic   = "Minimum"

  dimensions = {
    TargetGroup  = aws_lb_target_group.cloudcart_order_service.arn_suffix
    LoadBalancer = aws_lb.cloudcart_alb.arn_suffix
  }

  treat_missing_data = "breaching"

  alarm_actions = [
    aws_sns_topic.cloudcart_alerts.arn
  ]

  ok_actions = [
    aws_sns_topic.cloudcart_alerts.arn
  ]

  tags = local.common_tags
}
