# Public Application Load Balancer for CloudCart
resource "aws_lb" "cloudcart_alb" {
  name               = "cloudcart-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.cloudcart_alb_sg.id
  ]

  subnets = [
    aws_subnet.cloudcart_public_subnet_a.id,
    aws_subnet.cloudcart_public_subnet_b.id
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-ALB"
    }
  )
}

# Target group for Product Service ECS tasks
resource "aws_lb_target_group" "cloudcart_product_service" {
  name        = "cloudcart-product-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloudcart_vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Product-Service-TG"
    }
  )
}

# Listen for HTTP requests and forward them to the Product Service
resource "aws_lb_listener" "cloudcart_http" {
  load_balancer_arn = aws_lb.cloudcart_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudcart_product_service.arn
  }
}