# Main VPC for the CloudCart infrastructure
resource "aws_vpc" "cloudcart_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-VPC"
    }
  )
}


# Public subnet - Availability Zone A
resource "aws_subnet" "cloudcart_public_subnet_a" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Public-Subnet-A"
      Tier = "Public"
    }
  )
}

# Public subnet - Availability Zone B
resource "aws_subnet" "cloudcart_public_subnet_b" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Public-Subnet-B"
      Tier = "Public"
    }
  )
}

# Private application subnets for ECS/Fargate
resource "aws_subnet" "cloudcart_private_app_subnet_a" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Private-App-Subnet-A"
      Tier = "Private-App"
    }
  )
}

resource "aws_subnet" "cloudcart_private_app_subnet_b" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Private-App-Subnet-B"
      Tier = "Private-App"
    }
  )
}

# Private database subnets for RDS
resource "aws_subnet" "cloudcart_private_db_subnet_a" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Private-DB-Subnet-A"
      Tier = "Private-DB"
    }
  )
}

resource "aws_subnet" "cloudcart_private_db_subnet_b" {
  vpc_id            = aws_vpc.cloudcart_vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-Private-DB-Subnet-B"
      Tier = "Private-DB"
    }
  )
}