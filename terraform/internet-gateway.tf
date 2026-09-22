# Internet Gateway for the CloudCart VPC.
# An Internet Gateway allows resources in the VPC to communicate
# with the public internet when their route table sends traffic to it.
resource "aws_internet_gateway" "cloudcart_internet_gateway" {

  # Attach the Internet Gateway to the CloudCart VPC.
  vpc_id = aws_vpc.cloudcart_vpc.id

  # Apply the standard project tags and a resource-specific name.
  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Internet-Gateway"
    }
  )
}

