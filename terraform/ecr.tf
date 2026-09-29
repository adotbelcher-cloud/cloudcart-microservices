# ECR repository for the Product Service container image
resource "aws_ecr_repository" "cloudcart_product_service" {
  name                 = "cloudcart-product-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    local.common_tags, {
      Name = "CloudCart-Product-Service-ECR"
    }
  )
}

# ECR repository for the Order Service container image
resource "aws_ecr_repository" "cloudcart_order_service" {
  name                 = "cloudcart-order-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    local.common_tags, {
      Name = "CloudCart-Order-Service-ECR"
    }
  )
}