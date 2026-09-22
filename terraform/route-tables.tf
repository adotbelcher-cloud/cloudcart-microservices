# Public route table for CloudCart.
resource "aws_route_table" "cloudcart_public_route_table" {
  vpc_id = aws_vpc.cloudcart_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloudcart_internet_gateway.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Public-Route-Table"
    }
  )
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "cloudcart_public_subnet_a_association" {
  subnet_id      = aws_subnet.cloudcart_public_subnet_a.id
  route_table_id = aws_route_table.cloudcart_public_route_table.id
}

resource "aws_route_table_association" "cloudcart_public_subnet_b_association" {
  subnet_id      = aws_subnet.cloudcart_public_subnet_b.id
  route_table_id = aws_route_table.cloudcart_public_route_table.id
}



# Routes private application traffic through the NAT Gateway
resource "aws_route_table" "cloudcart_private_app_route_table" {
  vpc_id = aws_vpc.cloudcart_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cloudcart_nat_gateway.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Private-App-Route-Table"
    }
  )
}

# Associate both private app subnets with the private route table
resource "aws_route_table_association" "cloudcart_private_app_subnet_a_association" {
  subnet_id      = aws_subnet.cloudcart_private_app_subnet_a.id
  route_table_id = aws_route_table.cloudcart_private_app_route_table.id
}

resource "aws_route_table_association" "cloudcart_private_app_subnet_b_association" {
  subnet_id      = aws_subnet.cloudcart_private_app_subnet_b.id
  route_table_id = aws_route_table.cloudcart_private_app_route_table.id
}