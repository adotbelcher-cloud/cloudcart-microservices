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

# Target group for Order Service ECS tasks
resource "aws_lb_target_group" "cloudcart_order_service" {
  name        = "cloudcart-order-tg"
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
      Name = "CloudCart-Order-Service-TG"
    }
  )
}

# Accept incoming HTTP traffic on port 80
resource "aws_lb_listener" "cloudcart_http" {
  load_balancer_arn = aws_lb.cloudcart_alb.arn
  port              = 80
  protocol          = "HTTP"

  # Return 404 for requests that do not match a routing rule
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Route not found"
      status_code  = "404"
    }
  }
}

# Route product requests to Product Service
resource "aws_lb_listener_rule" "cloudcart_product_routing" {
  listener_arn = aws_lb_listener.cloudcart_http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudcart_product_service.arn
  }

  condition {
    path_pattern {
      values = ["/products", "/products/*"]
    }
  }
}

# Route order requests to Order Service
resource "aws_lb_listener_rule" "cloudcart_order_routing" {
  listener_arn = aws_lb_listener.cloudcart_http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cloudcart_order_service.arn
  }

  condition {
    path_pattern {
      values = ["/orders", "/orders/*"]
    }
  }
}