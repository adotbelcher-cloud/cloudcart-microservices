# Security group for the public Application Load Balancer
resource "aws_security_group" "cloudcart_alb_sg" {
  name        = "cloudcart-alb-sg"
  description = "Controls traffic to and from the CloudCart ALB"
  vpc_id      = aws_vpc.cloudcart_vpc.id

  tags = merge(
    local.common_tags, {
      Name = "CloudCart-ALB-SG"
    }
  )
}

# Allow HTTP traffic from the internet to the ALB
resource "aws_vpc_security_group_ingress_rule" "cloudcart_alb_http" {
  security_group_id = aws_security_group.cloudcart_alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# Allow outbound traffic from the ALB
resource "aws_vpc_security_group_egress_rule" "cloudcart_alb_egress" {
  security_group_id = aws_security_group.cloudcart_alb_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# Security group for ECS/Fargate application tasks
resource "aws_security_group" "cloudcart_ecs_sg" {
  name        = "cloudcart-ecs-sg"
  description = "Controls traffic to and from CloudCart ECS tasks"
  vpc_id      = aws_vpc.cloudcart_vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-ECS-SG"
    }
  )
}

# Allow application traffic from the ALB to ECS tasks
resource "aws_vpc_security_group_ingress_rule" "cloudcart_ecs_from_alb" {
  security_group_id = aws_security_group.cloudcart_ecs_sg.id

  referenced_security_group_id = aws_security_group.cloudcart_alb_sg.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
}

# Allow ECS tasks to initiate outbound connections
resource "aws_vpc_security_group_egress_rule" "cloudcart_ecs_egress" {
  security_group_id = aws_security_group.cloudcart_ecs_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# Security group for the CloudCart RDS database
resource "aws_security_group" "cloudcart_rds_sg" {
  name        = "cloudcart-rds-sg"
  description = "Controls traffic to and from the CloudCart RDS database"
  vpc_id      = aws_vpc.cloudcart_vpc.id

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-RDS-SG"
    }
  )
}

# Allow application traffic from the ALB to ECS tasks
resource "aws_vpc_security_group_ingress_rule" "cloudcart_rds_from_ecs" {
  security_group_id = aws_security_group.cloudcart_rds_sg.id

  referenced_security_group_id = aws_security_group.cloudcart_ecs_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}