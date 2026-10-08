# Private subnets available for RDS
resource "aws_db_subnet_group" "cloudcart" {
  name = "cloudcart-db-subnet-group"

  subnet_ids = [
    aws_subnet.cloudcart_private_db_subnet_a.id,
    aws_subnet.cloudcart_private_db_subnet_b.id
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-DB-Subnet-Group"
    }
  )
}

# PostgreSQL database for CloudCart
resource "aws_db_instance" "cloudcart_postgres" {
  identifier = "cloudcart-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class        = "db.t4g.small"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp2"

  db_name  = "cloudcart"
  username = "cloudcart_admin"

  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.cloudcart.name

  vpc_security_group_ids = [
    aws_security_group.cloudcart_rds_sg.id
  ]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = merge(
    local.common_tags,
    {
      Name = "CloudCart-PostgreSQL"
    }
  )
}