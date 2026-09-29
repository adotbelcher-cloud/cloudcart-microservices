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