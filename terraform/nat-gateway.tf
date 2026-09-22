# Elastic IP used by the NAT Gateway
resource "aws_eip" "cloudcart_nat_eip" {
  domain = "vpc"

  #   
  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-NAT-EIP"
    }
  )
}

# NAT Gateway provides outbound internet access for private app resources
# 
resource "aws_nat_gateway" "cloudcart_nat_gateway" {
  allocation_id = aws_eip.cloudcart_nat_eip.id
  subnet_id     = aws_subnet.cloudcart_public_subnet_a.id

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-NAT-Gateway"
    }
  )

  depends_on = [

    aws_internet_gateway.cloudcart_internet_gateway
  ]

}