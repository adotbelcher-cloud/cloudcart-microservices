# Key network resource IDs for CloudCart
output "vpc_id" {
  description = "ID of the CloudCart VPC"
  value       = aws_vpc.cloudcart_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value = [
    aws_subnet.cloudcart_public_subnet_a.id,
    aws_subnet.cloudcart_public_subnet_b.id
  ]
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets"
  value = [
    aws_subnet.cloudcart_private_app_subnet_a.id,
    aws_subnet.cloudcart_private_app_subnet_b.id
  ]
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets"
  value = [
    aws_subnet.cloudcart_private_db_subnet_a.id,
    aws_subnet.cloudcart_private_db_subnet_b.id
  ]
}

output "nat_gateway_id" {
  description = "ID of the CloudCart NAT Gateway"
  value       = aws_nat_gateway.cloudcart_nat_gateway.id
}